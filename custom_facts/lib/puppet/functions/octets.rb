Puppet::Functions.create_function(:octets) do
  dispatch :get_octets do
    param 'String', :address
  end

  def get_octets(address)
    address.split('.').map { |octet| octet.to_i }
  end
end