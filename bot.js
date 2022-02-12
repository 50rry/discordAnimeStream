import { Client } from 'discord.js'
import Handler from "./Commands/Handler.js";
import { botIntents }  from './config/config.js';
import config  from './config/default.js';

const client = new Client({
    intents: botIntents,
    partials: ['CHANNEL', 'MESSAGE'],
});

client.on('ready', () => {
    console.log('Logged in as ' + client.user.tag);
});

client.on('messageCreate', Handler.messageCreate.bind(Handler));

client.login(config.DISCORD_TOKEN);
