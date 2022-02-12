import {exec, spawn} from 'child_process';

export default class {
    static subprocess;
    static scriptRunning = false
    static prefix = '$';
    static commands = {
        getName: 'get-name',
        startCam: 'start-script',
    };

    static async messageCreate(msg) {
        if (msg.author.bot) return;
        if (!msg.content.startsWith(this.prefix)) return; // do nothing if command is not preceded with prefix

        const userCmd = msg.content.slice(this.prefix.length);

        if (this.scriptRunning) {
            this.subprocess.stdin.write(userCmd + "\n")
        } else if (userCmd === this.commands.startCam) {
            this.subprocess = spawn("./anibot.sh");
            this.subprocess.stdout.on('data', (data) => {
                this.scriptRunning = true
                msg.reply("" + data);
            });
            this.subprocess.on('exit', ()=>{
                msg.reply("script exited")
                this.scriptRunning = false;
                exec('killall ffmpeg');
            })
        }
    }
}