using Grpc.Core;
using Sentry;

namespace WorkTimeManager.Api.Tests;

public class SentryEventFilterTests
{
    private static SentryEvent? Run(Exception ex)
        => SentryEventFilter.Filter(new SentryEvent(ex), new SentryHint());

    [Fact]
    public void RpcExceptionCancelled_IsDropped()
    {
        var ex = new RpcException(new Status(StatusCode.Cancelled, "Call canceled by the client."));
        Assert.Null(Run(ex));
    }

    [Fact]
    public void OperationCanceled_IsDropped() => Assert.Null(Run(new OperationCanceledException()));

    [Fact]
    public void WrappedCancellation_IsDropped()
        => Assert.Null(Run(new InvalidOperationException("x", new OperationCanceledException())));

    [Fact]
    public void RpcExceptionOtherStatus_IsKept()
    {
        var ex = new RpcException(new Status(StatusCode.Unavailable, "down"));
        Assert.NotNull(Run(ex));
    }

    [Fact]
    public void GenericException_IsKept() => Assert.NotNull(Run(new InvalidOperationException("boom")));
}
