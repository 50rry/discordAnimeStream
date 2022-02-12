import { Intents } from 'discord.js';
const {
    DIRECT_MESSAGES,
    GUILD_MESSAGES,
    GUILDS,
} = Intents.FLAGS;

export const botIntents = [
    DIRECT_MESSAGES,
    GUILD_MESSAGES,
    GUILDS,
];
