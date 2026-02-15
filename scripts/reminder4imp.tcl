# telegram_notify.tcl
puts "===== 正在发送 Telegram 通知 ====="

# 替换为你自己的 Token 和 Chat ID
set bot_token "8350453564:AAHVYqpiT8V2iC4tgAVqoAeabBDUNkereC0"
set chat_id "8219313434"

# 你想收到的消息内容（可以自定义）
set msg "Vivado implementation finished!"

# 调用系统自带的 curl 发送请求给手机 (使用 catch 保证就算断网也不会报错中断 Vivado)
if {[catch {exec curl -s -X POST https://api.telegram.org/bot$bot_token/sendMessage -d chat_id=$chat_id -d text=$msg -d parse_mode=Markdown} err]} {
    puts "通知发送失败: $err"
} else {
    puts "Telegram 通知发送成功！"
}