using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Domain.Enums;
using LadderSocial.Infrastructure.Services;
using Xunit;

namespace LadderSocial.UnitTests;

public sealed class TaskStateMachineTests
{
    private readonly TaskStateMachine stateMachine = new();

    [Fact]
    public void CompletedTask_IsTerminalForOrdinaryEdit()
    {
        Assert.False(stateMachine.CanEdit(TaskItemStatus.Completed));
        Assert.False(stateMachine.CanComplete(TaskItemStatus.Completed));
        Assert.Empty(stateMachine.GetAllowedEditStatuses(TaskItemStatus.Completed));
        Assert.Throws<BusinessException>(() => stateMachine.EnsureEditTransition(
            TaskItemStatus.Completed,
            TaskItemStatus.Active));
    }

    [Fact]
    public void CompletedStatus_CanOnlyBeReachedThroughCompletionAction()
    {
        Assert.Throws<ValidationException>(() => stateMachine.EnsureEditTransition(
            TaskItemStatus.Active,
            TaskItemStatus.Completed));
    }

    [Fact]
    public void CancelledTask_CanBeReactivatedOrArchived()
    {
        stateMachine.EnsureEditTransition(
            TaskItemStatus.Cancelled,
            TaskItemStatus.Active);
        stateMachine.EnsureEditTransition(
            TaskItemStatus.Cancelled,
            TaskItemStatus.Archived);
    }

    [Fact]
    public void UndefinedNumericStatus_IsRejectedAtServiceBoundary()
    {
        Assert.Throws<ValidationException>(() =>
            stateMachine.ValidateDefinedStatus((TaskItemStatus)999));
    }
}
