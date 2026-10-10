using Grpc.Core;
using Sentry;

namespace WorkTimeManager.Api;

/// <summary>
/// Verwirft Sentry-Events, die nur entstehen, weil der Client den Request abgebrochen hat
/// (Tab/App geschlossen, Navigation, Timeout). Firestore meldet das als
/// <c>RpcException(Cancelled)</c> mit <see cref="OperationCanceledException"/> als Ursache -
/// kein Serverfehler (#438, #439, #440).
/// </summary>
public static class SentryClientCancellationFilter
{
    public static SentryEvent? Apply(SentryEvent sentryEvent, SentryHint hint)
        => IsClientCancellation(sentryEvent.Exception) ? null : sentryEvent;

    public static bool IsClientCancellation(Exception? exception)
    {
        for (var current = exception; current is not null; current = current.InnerException)
        {
            if (current is OperationCanceledException
                || current is RpcException { StatusCode: StatusCode.Cancelled })
            {
                return true;
            }
        }

        return false;
    }
}
