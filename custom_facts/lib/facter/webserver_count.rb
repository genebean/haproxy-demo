# webserver_count.rb
Facter.add(:webserver_count) do
  confine :kernel => 'Linux'
  setcode do
    count = Facter::Core::Execution.execute('cat /etc/webserver_count')
    if count
      count.to_i
    end
  end
end
