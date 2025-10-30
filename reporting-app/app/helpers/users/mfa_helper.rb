# frozen_string_literal: true

module Users::MfaHelper
  # Generate a QR code for setting up the TOTP device
  def totp_qr_code(secret, email)
    RQRCode::QRCode.new(totp_qr_code_uri(secret, email)).as_svg(
      offset: 0,
      color: "000",
      shape_rendering: "crispEdges",
      module_size: 3,
      standalone: true
    )
  end

  private
    def totp_qr_code_uri(secret, email)
      "otpauth://totp/#{email}?secret=#{secret}"
    end
end
