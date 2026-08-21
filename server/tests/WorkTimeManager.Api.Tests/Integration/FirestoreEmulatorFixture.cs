using DotNet.Testcontainers.Builders;
using DotNet.Testcontainers.Containers;
using Google.Api.Gax;
using Google.Cloud.Firestore;

namespace WorkTimeManager.Api.Tests.Integration;

/// <summary>
/// Startet den Google-Firestore-Emulator als Docker-Container (da kein lokales Java vorhanden).
/// Schlägt der Start fehl (kein Docker / kein Image-Pull), bleibt <see cref="SkipReason"/> gesetzt
/// und die Integrationstests überspringen sich selbst — <c>dotnet test</c> bleibt grün.
/// </summary>
public sealed class FirestoreEmulatorFixture : IAsyncLifetime
{
    private const string Image = "gcr.io/google.com/cloudsdktool/google-cloud-cli:emulators";
    private const int EmulatorPort = 8080;
    public const string ProjectId = "worktime-test";

    private IContainer? _container;

    public FirestoreDb? Db { get; private set; }
    public string? SkipReason { get; private set; }

    public async Task InitializeAsync()
    {
        try
        {
            _container = new ContainerBuilder()
                .WithImage(Image)
                .WithCommand("gcloud", "emulators", "firestore", "start",
                    $"--host-port=0.0.0.0:{EmulatorPort}")
                .WithPortBinding(EmulatorPort, assignRandomHostPort: true)
                .WithWaitStrategy(Wait.ForUnixContainer().UntilMessageIsLogged("running"))
                .Build();

            await _container.StartAsync();

            var endpoint = $"{_container.Hostname}:{_container.GetMappedPublicPort(EmulatorPort)}";
            Environment.SetEnvironmentVariable("FIRESTORE_EMULATOR_HOST", endpoint);

            Db = new FirestoreDbBuilder
            {
                ProjectId = ProjectId,
                EmulatorDetection = EmulatorDetection.EmulatorOnly,
            }.Build();
        }
        catch (Exception ex)
        {
            SkipReason = $"Firestore-Emulator nicht verfügbar (Docker erforderlich): {ex.Message}";
        }
    }

    public async Task DisposeAsync()
    {
        if (_container is not null)
        {
            await _container.DisposeAsync();
        }
    }
}

[CollectionDefinition(Name)]
public sealed class FirestoreEmulatorCollection : ICollectionFixture<FirestoreEmulatorFixture>
{
    public const string Name = "Firestore Emulator";
}
