Rails.application.config.middleware.insert_before(Rails.application.config.session_store, 
                                                 FlashSessionCookieMiddleware, 
                                                 Rails.application.config.session_options[:key])
