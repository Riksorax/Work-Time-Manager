using System.Security.Claims;

namespace WorkTimeManager.Api.Endpoints;

internal static class ClaimsPrincipalExtensions
{
    /// <summary>Firebase-UID aus dem ID-Token (<c>user_id</c> bzw. <c>sub</c>).</summary>
    public static string? GetUid(this ClaimsPrincipal user) =>
        user.FindFirst("user_id")?.Value
        ?? user.FindFirst("sub")?.Value
        ?? user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
}
