using Grpc.Core;
using Sentry;
using WorkTimeManager.Api;

namespace WorkTimeManager.Api.Tests;

public class ClientCancellationFilterTests
{
    [Fact]
    public void RpcExceptionCancelled_IsDropped()
    {
        var ex = new RpcException(new Status(StatusCode.Cancelled, "Call canceled by the client."),
            "x");
        Assert.Null(ClientCancellationFilter.Apply(new SentryEvent(ex), new SentryHint()));
    }

    [Fact]
    public void OperationCanceled_IsDropped()
    {
        var ev = new SentryEvent(new OperationCanceledException());
        Assert.Null(ClientCancellationFilter.Apply(ev, new SentryHint()));
    }

    [Fact]
    public void WrappedCancellation_IsDropped()
    {
        var ex = new InvalidOperationException("w", new OperationCanceledException());
        Assert.Null(ClientCancellationFilter.Apply(new SentryEvent(ex), new SentryHint()));
    }

    [Fact]
    public void OtherRpcException_IsKept()
    {
        var ev = new SentryEvent(new RpcException(new Status(StatusCode.Unavailable, "down")));
        Assert.Same(ev, ClientCancellationFilter.Apply(ev, new SentryHint()));
    }

    [Fact]
    public void EventWithoutException_IsKept()
    {
        var ev = new SentryEvent();
        Assert.Same(ev, ClientCancellationFilter.Apply(ev, new SentryHint()));
    }
}
