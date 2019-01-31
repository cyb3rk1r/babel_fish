require './bin/worker'

dt = Time.now.utc
notify_at = format('%02d-%d0', dt.hour, dt.min/20*2) # magic
scheduled_notifies = NotifySchedule.where(enabled: true, notify_at: notify_at )
chat_ids = scheduled_notifies.all.map do |schedule|
  schedule[:chat_id]
end.uniq

chat_ids.each {|chat_id| Worker.perform_async(chat_id)}
