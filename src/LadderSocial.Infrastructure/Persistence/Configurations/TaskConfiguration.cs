using LadderSocial.Domain.Entities;
using LadderSocial.Infrastructure.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LadderSocial.Infrastructure.Persistence.Configurations;

public sealed class TaskItemConfiguration : IEntityTypeConfiguration<TaskItem>
{
    public void Configure(EntityTypeBuilder<TaskItem> builder)
    {
        builder.ToTable("Tasks");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Title).HasMaxLength(200).IsRequired();
        builder.Property(x => x.Description).HasMaxLength(2000);
        builder.HasIndex(x => new { x.OwnerUserId, x.Status, x.DueAtUtc });

        builder.HasOne<AppUser>().WithMany().HasForeignKey(x => x.OwnerUserId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<TaskCategory>().WithMany().HasForeignKey(x => x.TaskCategoryId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<RecurrenceType>().WithMany().HasForeignKey(x => x.RecurrenceTypeId).OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class TaskCompletionConfiguration : IEntityTypeConfiguration<TaskCompletion>
{
    public void Configure(EntityTypeBuilder<TaskCompletion> builder)
    {
        builder.ToTable("TaskCompletions");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Note).HasMaxLength(1000);
        builder.Property(x => x.OccurrenceDate).HasColumnType("date");
        builder.HasIndex(x => new { x.UserId, x.CompletedAtUtc });
        builder.HasIndex(x => new { x.TaskItemId, x.UserId, x.OccurrenceDate }).IsUnique();

        builder.HasOne<TaskItem>().WithMany().HasForeignKey(x => x.TaskItemId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<AppUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class TaskProofMediaConfiguration : IEntityTypeConfiguration<TaskProofMedia>
{
    public void Configure(EntityTypeBuilder<TaskProofMedia> builder)
    {
        builder.ToTable("TaskProofMedia");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.StorageKey).HasMaxLength(500).IsRequired();
        builder.Property(x => x.MimeType).HasMaxLength(100).IsRequired();
        builder.HasIndex(x => x.TaskCompletionId).IsUnique();
        builder.HasOne<TaskCompletion>().WithMany().HasForeignKey(x => x.TaskCompletionId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<AppUser>().WithMany().HasForeignKey(x => x.OwnerUserId).OnDelete(DeleteBehavior.Restrict);
    }
}
