-- Server-only secrets. Never put these in shared/config.lua (clients download that file).
SvConfig = {}

-- Fivemanage (Config.Images.Enabled = true). Dashboard -> Tokens. The token needs file upload + delete.
SvConfig.Fivemanage = {
    ApiKey = '',
    BaseUrl = 'https://api.fivemanage.com/api/v3',
}

-- Discord approval bot (Config.Approval.Discord.Enabled = true).
-- Create an application + bot at https://discord.com/developers, invite it to your server with
-- View Channel, Send Messages, Embed Links, Add Reactions and Read Message History on the channel below.
SvConfig.Discord = {
    BotToken = '',
    GuildId = '',
    ChannelId = '',
    ApproverRoles = {},                  -- role ids (strings) whose ✅ / ❌ reactions count
}
