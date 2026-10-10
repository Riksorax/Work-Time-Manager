using Grpc.Core;
using Sentry;
using WorkTimeManager.Api;

namespace WorkTimeManager.Api.Tests;

public class SentryClientCancellationFilterTests
{
    [Fact]
    public void RpcExceptionCancelled_IsClientCancellation()
    {
        var ex = new RpcException(new Status(StatusCode.Cancelled, "Call canceled by the client.", new OperationCanceledException()));

        Assert.True(SentryClientCancellationFilter.IsClientCancellation(ex));
    }

    [Fact]
    public void OperationCanceled_IsClientCancellation()
        => Assert.True(SentryClientCancellationFilter.IsClientCancellation(new TaskCanceledException()));

    [Fact]
    public void WrappedCancellation_IsClientCancellation()
        => Assert.True(SentryClientCancellationFilter.IsClientCancellation(
            new InvalidOperationException("x", new OperationCanceledException())));

    [Fact]
    public void OtherRpcError_IsNotClientCancellation()
        => Assert.False(SentryClientCancellationFilter.IsClientCancellation(
            new RpcException(new Status(StatusCode.Unavailable, "down"))));

    [Fact]
    public void NullOrPlainException_IsNotClientCancellation()
    {
        Assert.False(SentryClientCancellationFilter.IsClientCancellation(null));
        Assert.False(SentryClientCancellationFilter.IsClientCancellation(new InvalidOperationException()));
    }

    [Fact]
    public void Apply_DropsCancelledEvent_KeepsOthers()
    {
        var hint = new SentryHint();
        var cancelled = new SentryEvent(new OperationCanceledException());
        var failure = new SentryEvent(new InvalidOperationException());

        Assert.Null(SentryClientCancellationFilter.Apply(cancelled, hint));
        Assert.Same(failure, SentryClientCancellationFilter.Apply(failure, hint));
    }
}
