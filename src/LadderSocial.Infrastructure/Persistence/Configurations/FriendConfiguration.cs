using LadderSocial.Domain.Entities;
using LadderSocial.Infrastructure.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LadderSocial.Infrastructure.Persistence.Configurations;

public sealed class FriendRequestConfiguration : IEntityTypeConfiguration<FriendRequest>
{
    public void Configure(EntityTypeBuilder<FriendRequest> builder)
    {
        builder.ToTable("FriendRequests", table =>
            table.HasCheckConstraint("CK_FriendRequests_DifferentUsers", "[SenderUserId] <> [ReceiverUserId]"));
        builder.HasKey(x => x.Id);
        builder.HasIndex(x => new { x.SenderUserId, x.ReceiverUserId, x.Status });

        builder.HasOne<AppUser>().WithMany().HasForeignKey(x => x.SenderUserId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<AppUser>().WithMany().HasForeignKey(x => x.ReceiverUserId).OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class FriendshipConfiguration : IEntityTypeConfiguration<Friendship>
{
    public void Configure(EntityTypeBuilder<Friendship> builder)
    {
        builder.ToTable("Friendships", table =>
            table.HasCheckConstraint("CK_Friendships_DifferentUsers", "[UserId] <> [FriendUserId]"));
        builder.HasKey(x => x.Id);
        builder.HasIndex(x => new { x.UserId, x.FriendUserId }).IsUnique();

        builder.HasOne<AppUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<AppUser>().WithMany().HasForeignKey(x => x.FriendUserId).OnDelete(DeleteBehavior.Restrict);
    }
}
