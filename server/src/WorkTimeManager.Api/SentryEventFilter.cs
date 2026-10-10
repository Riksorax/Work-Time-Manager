using Grpc.Core;
using Sentry;

namespace WorkTimeManager.Api;

/// <summary>
/// Verwirft Sentry-Events, die nur vom Abbruch eines Requests durch den Client stammen
/// (#438/#439/#440): Bricht der Client ab, wird das Firestore-gRPC-Call als
/// <c>Cancelled</c> beendet bzw. eine <see cref="OperationCanceledException"/> geworfen.
/// Das ist kein Serverfehler.
/// </summary>
public static class SentryEventFilter
{
    public static SentryEvent? Filter(SentryEvent sentryEvent, SentryHint hint)
        => IsClientCancellation(sentryEvent.Exception) ? null : sentryEvent;

    public static bool IsClientCancellation(Exception? exception)
    {
        for (var ex = exception; ex is not null; ex = ex.InnerException)
        {
            if (ex is OperationCanceledException) return true;
            if (ex is RpcException { StatusCode: StatusCode.Cancelled }) return true;
        }
        return false;
    }
}
