require 'pathname'
Puppet::Type.newtype(:x509_cert) do
  desc 'An x509 certificate'

  ensurable

  newparam(:path, :namevar => true) do
    desc 'The path to the certificate'
    validate do |value|
      path = Pathname.new(value)
      unless path.absolute?
        raise ArgumentError, "Path must be absolute: #{path}"
      end
    end
  end

  newparam(:private_key) do
    desc 'The path to the private key'
    defaultto do
      path = Pathname.new(@resource[:path])
      "#{path.dirname}/#{path.basename(path.extname)}.key"
    end
    validate do |value|
      path = Pathname.new(value)
      unless path.absolute?
        raise ArgumentError, "Path must be absolute: #{path}"
      end
    end
  end

  newparam(:days) do
    desc 'The validity of the certificate'
    newvalues(/\d+/)
    defaultto(3650)
  end

  newparam(:force, :boolean => true) do
    desc 'Whether to replace the certificate if the private key mismatches'
    newvalues(:true, :false)
    defaultto false
  end

  newparam(:password) do
    desc 'The optional password for the private key'
  end

  newparam(:req_ext, :boolean => true) do
    desc 'Whether adding v3 SAN from config'
    newvalues(:true, :false)
    defaultto false
  end

  newparam(:ca) do
    desc 'If this certificate should be a self-signed Certificate Authority'
  end

  newparam(:template) do
    desc 'The template to use'
    defaultto do
      path = Pathname.new(@resource[:path])
      "#{path.dirname}/#{path.basename(path.extname)}.cnf"
    end
    validate do |value|
      path = Pathname.new(value)
      unless path.absolute?
        raise ArgumentError, "Path must be absolute: #{path}"
      end
    end
  end

  newparam(:authority_cnf) do
    desc 'The CA configuration template to use when signing certificates'
    defaultto(undef)

  newparam(:request) do
    desc 'The certificate signing request to use'
    validate do |value|
      path = Pathname.new(value)
      unless path.absolute?
        raise ArgumentError, "Path must be absolute: #{path}"
      end
    end
  end

  newparam(:server_only, :boolean => true) do
    desc "If true, will generate a server only certificate"
    defaultto(false)
  end

  newparam(:client_only, :boolean => true) do
    desc "If true, will generate a client only certificate"
    defaultto(false)
  end

  newparam(:authentication) do
    desc "The authentication algorithm: 'rsa' or 'dsa'"
    newvalues /[dr]sa/
    defaultto :rsa
  end

  autorequire(:file) do
    self[:template]
  end

  autorequire(:ssl_pkey) do
    self[:private_key]
  end

  autorequire(:file) do
    self[:private_key]
  end

  def refresh
    provider.create
  end
end
