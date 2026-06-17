using System.Text;
using Google.Apis.Auth.OAuth2;
using Google.Cloud.Firestore;
using Google.Cloud.Firestore.V1;

namespace WorkTimeManager.Api.Firestore;

public static class FirestoreServiceCollectionExtensions
{
    private const string ServiceAccountEnvVar = "FIREBASE_SERVICE_ACCOUNT_BASE64";

    public static IServiceCollection AddFirestoreClient(this IServiceCollection services, IConfiguration configuration)
    {
        var projectId = configuration["Firebase:ProjectId"]
            ?? throw new InvalidOperationException("Firebase:ProjectId is not configured.");

        services.AddSingleton(_ =>
        {
            var clientBuilder = new FirestoreClientBuilder { Credential = ResolveCredential() };
            return FirestoreDb.Create(projectId, clientBuilder.Build());
        });

        return services;
    }

    private static GoogleCredential ResolveCredential()
    {
        var base64 = Environment.GetEnvironmentVariable(ServiceAccountEnvVar);
        if (string.IsNullOrWhiteSpace(base64))
        {
            return GoogleCredential.GetApplicationDefault();
        }

        var json = Encoding.UTF8.GetString(Convert.FromBase64String(base64));
        return CredentialFactory.FromJson<ServiceAccountCredential>(json).ToGoogleCredential();
    }
}
