require 'pathname'
Puppet::Type.type(:x509_cert).provide(:openssl) do
  desc 'Manages certificates with OpenSSL'

  commands :openssl => 'openssl'

  def self.private_key(resource)
    file = File.read(resource[:private_key])
    if resource[:authentication] == :dsa
      OpenSSL::PKey::DSA.new(file, resource[:password])
    elsif resource[:authentication] == :rsa
      OpenSSL::PKey::RSA.new(file, resource[:password])
    else
      raise Puppet::Error,
            "Unknown authentication type '#{resource[:authentication]}'"
    end
  end

  def self.check_private_key(resource)
    cert = OpenSSL::X509::Certificate.new(File.read(resource[:path]))
    priv = self.private_key(resource)
    cert.check_private_key(priv)
  end

  def self.old_cert_is_equal(resource)
    cert = OpenSSL::X509::Certificate.new(File.read(resource[:path]))

    altName = ''
    cert.extensions.each do |ext|
      altName = ext.value if ext.oid == 'subjectAltName'
    end

    cdata = {}
    cert.subject.to_s.split('/').each do |name|
      k,v = name.split('=')
        cdata[k] = v
    end

    require 'puppet/util/inifile'
    ini_file  = Puppet::Util::IniConfig::PhysicalFile.new(resource[:template])
    if (req_ext = ini_file.get_section('req_ext'))
      if (value = req_ext['subjectAltName'])
        return false if value.delete(' ').gsub(/^"|"$/, '') != altName.delete(' ').gsub(/^"|"$/, '').gsub('IPAddress','IP')
      end
    elsif (req_dn = ini_file.get_section('req_distinguished_name'))
      if (value = req_dn['commonName'])
        return false if value != cdata['CN']
      end
    end
    return true
  end

  def exists?
    if Pathname.new(resource[:path]).exist?
      if resource[:force] and !self.class.check_private_key(resource)
        return false
      end
      if !self.class.old_cert_is_equal(resource)
        return false
      end
      return true
    else
      return false
    end
  end

  def create
    if resource[:request]
      options = [
        'ca',
        '-create_serial',
        '-batch',
        '-in', resource[:request],
      ]
      options << ['-config', resource[:authority_cnf]]
    else
      options = [
        'req',
        '-new',
        '-key', resource[:private_key],
      ]

      options << '-x509' if resource[:ca]
      options << ['-config', resource[:template]]

      if resource[:days]
        options << ['-days', resource[:days]]
      end

      if resource[:password]
        options << "-passin pass:#{resource[:password]}"
      else
        options << '-nodes'
      end
      options << ['-extensions', "req_ext",] if resource[:req_ext] != :false
    end

    options << ['-out', resource[:path]]

    # NICKG, see templates/openssl.cnf.erb
    if resource[:server_only] and resource[:client_only]
      options << ['-extensions', 'ssl_both'] 
    elsif resource[:client_only]
      options << ['-extensions', 'clientAuth']
    elsif resource[:server_only]
      options << ['-extensions', 'serverAuth']
    end

    Puppet.info("Running openssl with options '#{options}'")
    openssl(options)
  end

  def destroy
    Pathname.new(resource[:path]).delete
  end
end
