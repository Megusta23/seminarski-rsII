using LadderSocial.Domain.Entities;
using LadderSocial.Infrastructure.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LadderSocial.Infrastructure.Persistence.Configurations;

public sealed class ConversationConfiguration : IEntityTypeConfiguration<Conversation>
{
    public void Configure(EntityTypeBuilder<Conversation> builder)
    {
        builder.ToTable("Conversations");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Title).HasMaxLength(200);
        builder.HasIndex(x => x.LastMessageAtUtc);
    }
}

public sealed class ConversationParticipantConfiguration : IEntityTypeConfiguration<ConversationParticipant>
{
    public void Configure(EntityTypeBuilder<ConversationParticipant> builder)
    {
        builder.ToTable("ConversationParticipants");
        builder.HasKey(x => x.Id);
        builder.HasIndex(x => new { x.ConversationId, x.UserId }).IsUnique();
        builder.HasOne<Conversation>().WithMany().HasForeignKey(x => x.ConversationId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<AppUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne<Message>().WithMany().HasForeignKey(x => x.LastReadMessageId).OnDelete(DeleteBehavior.NoAction);
    }
}

public sealed class UserDeviceKeyConfiguration : IEntityTypeConfiguration<UserDeviceKey>
{
    public void Configure(EntityTypeBuilder<UserDeviceKey> builder)
    {
        builder.ToTable("UserDeviceKeys");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.DeviceId).HasMaxLength(128).IsRequired();
        builder.Property(x => x.PublicKey).HasMaxLength(32).IsRequired();
        builder.HasIndex(x => new { x.UserId, x.DeviceId }).IsUnique();
        builder.HasIndex(x => new { x.UserId, x.RevokedAtUtc });
        builder.HasOne<AppUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class ConversationKeyEnvelopeConfiguration : IEntityTypeConfiguration<ConversationKeyEnvelope>
{
    public void Configure(EntityTypeBuilder<ConversationKeyEnvelope> builder)
    {
        builder.ToTable("ConversationKeyEnvelopes");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.EncryptedConversationKey).HasMaxLength(64).IsRequired();
        builder.Property(x => x.Nonce).HasMaxLength(24).IsRequired();
        builder.HasIndex(x => new { x.ConversationId, x.RecipientDeviceKeyId, x.KeyVersion }).IsUnique();
        builder.HasIndex(x => x.RecipientDeviceKeyId);
        builder.HasIndex(x => x.SenderDeviceKeyId);
        builder.HasOne<Conversation>().WithMany().HasForeignKey(x => x.ConversationId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<UserDeviceKey>().WithMany().HasForeignKey(x => x.RecipientDeviceKeyId).OnDelete(DeleteBehavior.NoAction);
        builder.HasOne<UserDeviceKey>().WithMany().HasForeignKey(x => x.SenderDeviceKeyId).OnDelete(DeleteBehavior.NoAction);
    }
}

public sealed class MessageConfiguration : IEntityTypeConfiguration<Message>
{
    public void Configure(EntityTypeBuilder<Message> builder)
    {
        builder.ToTable("Messages");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.Content).HasMaxLength(4000);
        builder.Property(x => x.EncryptedContent).HasColumnType("varbinary(max)");
        builder.Property(x => x.ContentNonce).HasMaxLength(24);
        builder.HasIndex(x => new { x.ConversationId, x.SentAtUtc });
        builder.HasOne<Conversation>().WithMany().HasForeignKey(x => x.ConversationId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<AppUser>().WithMany().HasForeignKey(x => x.SenderUserId).OnDelete(DeleteBehavior.Restrict);
    }
}

public sealed class MessageAttachmentConfiguration : IEntityTypeConfiguration<MessageAttachment>
{
    public void Configure(EntityTypeBuilder<MessageAttachment> builder)
    {
        builder.ToTable("MessageAttachments");
        builder.HasKey(x => x.Id);
        builder.Property(x => x.StorageKey).HasMaxLength(500).IsRequired();
        builder.Property(x => x.MimeType).HasMaxLength(100).IsRequired();
        builder.Property(x => x.ContentNonce).HasMaxLength(24);
        builder.HasIndex(x => x.MessageId).IsUnique();
        builder.HasOne<Message>().WithMany().HasForeignKey(x => x.MessageId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<AppUser>().WithMany().HasForeignKey(x => x.OwnerUserId).OnDelete(DeleteBehavior.Restrict);
    }
}
