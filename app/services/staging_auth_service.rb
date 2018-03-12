class StagingAuthService
  def self.authenticate(username, password)
    if enabled?
      username == Rails.application.secrets.basic_auth[:username] && password == Rails.application.secrets.basic_auth[:password]
    else
      true
    end
  end

  def self.enabled?
    !!Rails.application.secrets.basic_auth[:enabled]
  end
end
