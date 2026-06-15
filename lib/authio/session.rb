# frozen_string_literal: true

module Authio
  # A verified Authio session. `user_id` is always set; `org_id` may be
  # nil when the user authenticated but has not yet selected one of
  # their memberships.
  Session = Struct.new(
    :session_id,
    :user_id,
    :org_id,
    :role,
    :expires_at,
    :claims,
    :impersonation?,
    :impersonator_email,
    keyword_init: true,
  ) do
    def to_h
      {
        session_id: session_id,
        user_id: user_id,
        org_id: org_id,
        role: role,
        expires_at: expires_at,
        claims: claims || {},
        is_impersonation: impersonation? == true,
        impersonator_email: impersonator_email,
      }
    end
  end
end
