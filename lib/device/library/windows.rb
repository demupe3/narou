# frozen_string_literal: true

#
# Copyright 2013 whiteleaf. All rights reserved.
#

# rubocop:disable Naming/VariableName

require "win32ole"
require_relative "../../extensions/windows"
require_relative "windows/eject"

class Device
  module Library
    module Windows
      def kindle_mtp(action, source = nil)
        require "open3"
        script = File.expand_path("kindle_mtp.ps1", __dir__)
        args = ["powershell.exe", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", script, "-Action", action]
        args.concat(["-Source", File.expand_path(source)]) if source
        out, err, status = Open3.capture3(*args)
        unless status.success?
          raise Device::SendFailure, "Kindle MTP処理に失敗しました: #{err.force_encoding(Encoding::UTF_8).scrub.strip}"
        end
        out.force_encoding(Encoding::UTF_8).scrub.strip
      end

      def kindle_mtp_connected?
        kindle_mtp("detect") == "YES"
      rescue Device::SendFailure
        false
      end
      def get_device_root_dir(volume_name)
        @@FileSystemObject ||= WIN32OLE.new("Scripting.FileSystemObject")
        drives.each do |drive_letter|
          drive_info = @@FileSystemObject.GetDrive(drive_letter)
          vol = drive_info.VolumeName rescue ""
          if vol.casecmp(volume_name) == 0
            return File.expand_path(drive_letter)
          end
        end
        nil
      end

      def drives
        result = []
        bits = WinAPI.GetLogicalDrives
        26.times do |i|
          if bits & (1 << i) != 0
            result << "#{(65 + i).chr}:\\"
          end
        end
        result
      end
    end
  end
end
