using Grpc.Core;
using Sentry;

namespace WorkTimeManager.Api;

/// <summary>
/// Verwirft Sentry-Events für Requests, die der Client selbst abgebrochen hat
/// (Navigation, Profilwechsel, Netzwechsel). Firestore meldet das als
/// <c>RpcException(Cancelled)</c> bzw. <see cref="OperationCanceledException"/> -
/// kein Serverfehler (#438, #439, #440).
/// </summary>
public static class ClientCancellationFilter
{
    public static SentryEvent? Apply(SentryEvent sentryEvent, SentryHint hint)
        => IsClientCancellation(sentryEvent.Exception) ? null : sentryEvent;

    public static bool IsClientCancellation(Exception? exception)
    {
        for (var e = exception; e is not null; e = e.InnerException)
        {
            if (e is OperationCanceledException) return true;
            if (e is RpcException { StatusCode: StatusCode.Cancelled }) return true;
        }
        return false;
    }
}
