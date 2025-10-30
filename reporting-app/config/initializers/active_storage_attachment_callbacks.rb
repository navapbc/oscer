# frozen_string_literal: true

# If a model uses Active Storage and it defines any of the defined methods (after_commit,
# after_create_commit, or after_update_commit), then those methods will be called after
# the attachment has been fully committed to database. This allows for post-processing
# after uploads, since uploads are not immediately available.
#
# 🎩 Hat tip and thanks to:
# - https://redgreen.no/2021/01/25/active-storage-callbacks.html
# - https://stackoverflow.com/questions/53226228/callback-for-active-storage-file-upload
Rails.configuration.to_prepare do
  module ActiveStorage::Attachment::Callbacks
    # Gives us some convenient shortcuts, like `prepended`
    extend ActiveSupport::Concern

    # When prepended into a class, define our callback
    prepended do
      after_commit :after_commit
      after_create_commit :after_create_commit
      after_update_commit :after_update_commit
    end

    # Callback methods
    def after_commit
      record.after_attachment_commit(self) if record.respond_to? :after_attachment_commit
    end

    def after_create_commit
      record.after_attachment_create_commit(self) if record.respond_to? :after_attachment_create_commit
    end

    def after_update_commit
      record.after_attachment_update_commit(self) if record.respond_to? :after_attachment_update_commit
    end
  end

  # After defining the module, call on ActiveStorage::Attachment to prepend it in.
  ActiveStorage::Attachment.prepend ActiveStorage::Attachment::Callbacks
end
