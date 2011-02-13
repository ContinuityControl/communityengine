module PostsHelper

  # The ShareThis widget defines a bunch of attributes you can customize.
  # Facebook seems to ignore them (it uses title and description meta tags
  # instead).  MySpace, however, only works if you set these attributes.
  def sharethis_options(post)
    javascript_tag do 
      <<-eos
        var shared_object = SHARETHIS.addEntry({
          title: document.title,
          url: document.location.href
        });

        shared_object.attachButton(document.getElementById("ck_sharethis"));
        shared_object.attachChicklet("facebook", document.getElementById("ck_facebook"));
        shared_object.attachChicklet("twitter", document.getElementById("ck_twitter"));
      eos
    end
  end

end
