class PlayCpuJob < ApplicationJob
  class_timeout 300 # 300s or 5m, current Lambda max is 15m

  iam_policy "lambda" # required to run Jobs
  def play
    puts "Starting delay + cpu player.  Sleeping: #{event['sleep']}"
    sleep(event['sleep'].to_f)
    game = Game.find(event['game_id'])

    return unless game.table_state['state'] == 'WAITING_TO_PLAY'

    game.play_cpu(1)
    game.replace

    if game.next_player_cpu?
      puts "Still not done, queueing up another...."
      PlayCpuJob.perform_later(:play, {game_id: game.id, sleep: game.settings['cpu_wait_time']})
    end
    puts "\n-----------------"
  end
end