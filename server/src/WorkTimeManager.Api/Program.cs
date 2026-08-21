using System.Security.Claims;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.OpenApi;
using WorkTimeManager.Api.Endpoints;
using WorkTimeManager.Api.Firestore;

var builder = WebApplication.CreateBuilder(args);

var firebaseProjectId = builder.Configuration["Firebase:ProjectId"]
    ?? throw new InvalidOperationException("Firebase:ProjectId is not configured.");

var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()
    ?? Array.Empty<string>();

// ── Authentication: Firebase ID Tokens (JWT Bearer, JWKS-validiert) ────────
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = $"https://securetoken.google.com/{firebaseProjectId}";
        options.Audience = firebaseProjectId;
        options.TokenValidationParameters.ValidIssuer = $"https://securetoken.google.com/{firebaseProjectId}";
    });

builder.Services.AddAuthorization();

// ── CORS ─────────────────────────────────────────────────────────────────
const string CorsPolicyName = "WebClients";
builder.Services.AddCors(options =>
{
    options.AddPolicy(CorsPolicyName, policy =>
        policy.WithOrigins(allowedOrigins).AllowAnyHeader().AllowAnyMethod());
});

// ── Firestore-Client (DI-Wiring für Phase 1) ────────────────────────────────
builder.Services.AddFirestoreClient(builder.Configuration);

// ── Swagger / OpenAPI ────────────────────────────────────────────────────
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo { Title = "Work Time Manager API", Version = "v1" });
    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "Firebase ID Token. Eingabe als: Bearer {token}",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });
    options.AddSecurityRequirement(document => new OpenApiSecurityRequirement
    {
        [new OpenApiSecuritySchemeReference("Bearer", document)] = new List<string>()
    });
});

var app = builder.Build();

if (builder.Configuration.GetValue<bool>("Swagger:Enabled"))
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors(CorsPolicyName);
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/health", () => Results.Ok(new { status = "healthy" }))
   .WithName("Health")
   .AllowAnonymous();

app.MapGet("/api/me", (ClaimsPrincipal user) => Results.Ok(new { uid = user.GetUid() }))
   .RequireAuthorization()
   .WithName("Me");

// ── Geschäftslogik-Endpunkte (alle authentifiziert) ────────────────────────
var api = app.MapGroup("/api").RequireAuthorization();
api.MapWorkEntryEndpoints();
api.MapOvertimeEndpoints();
api.MapSettingsEndpoints();
api.MapProfileEndpoints();
api.MapReportEndpoints();

app.Run();

public partial class Program { }
