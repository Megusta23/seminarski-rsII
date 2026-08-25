using LadderSocial.Domain.Entities;
using LadderSocial.Infrastructure.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LadderSocial.Infrastructure.Persistence.Configurations;

public sealed class PostConfiguration : IEntityTypeConfiguration<Post>
{
    public void Configure(EntityTypeBuilder<Post> builder)
    {
        builder.ToTable("Posts");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Caption).HasMaxLength(1000);
        builder.HasIndex(x => new { x.AuthorUserId, x.CreatedAtUtc });
        builder.HasIndex(x => new { x.AuthorUserId, x.IsHighlighted, x.HighlightedAtUtc });
        builder.HasOne<AppUser>().WithMany().HasForeignKey(x => x.AuthorUserId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<TaskCompletion>().WithOne().HasForeignKey<Post>(x => x.TaskCompletionId).OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class PostViewConfiguration : IEntityTypeConfiguration<PostView>
{
    public void Configure(EntityTypeBuilder<PostView> builder)
    {
        builder.ToTable("PostViews");
        builder.HasKey(x => x.Id);
        builder.HasIndex(x => new { x.PostId, x.ViewerUserId }).IsUnique();
        builder.HasOne<Post>().WithMany().HasForeignKey(x => x.PostId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<AppUser>().WithMany().HasForeignKey(x => x.ViewerUserId).OnDelete(DeleteBehavior.Restrict);
    }
}
