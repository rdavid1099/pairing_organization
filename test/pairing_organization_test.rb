require 'minitest/autorun'
require 'minitest/pride'
require 'pry'
require './lib/pairing_organization'

class TestPairingOrganization < Minitest::Test
  def test_it_exists
    ds = PairingOrganization::DownloadSpreadsheet.new

    assert_instance_of PairingOrganization::DownloadSpreadsheet, ds
  end

  def test_it_downloads_csv_from_google_docs
    ds = PairingOrganization::DownloadSpreadsheet.new
    ds.download_google_docs
    document_name = "./temp/#{Time.now.to_s[0..9]}.csv"

    assert_equal true, File.exist?(document_name)
  end

  def test_it_reads_spreadsheet
    rs = PairingOrganization::ReadSpreadsheet.new

    assert_instance_of Array, rs.contents
  end

  def test_it_generates_booking_dates
    rs = PairingOrganization::ReadSpreadsheet.new

    assert_equal 18, rs.generate_booking_dates.length
    assert_instance_of Array, rs.generate_booking_dates
    assert_equal Time.parse("Tuesday, 8/16"), rs.generate_booking_dates[0]
  end

  def test_it_divides_array_into_hash_of_dates_and_times
    rs = PairingOrganization::ReadSpreadsheet.new

    assert_equal 13, rs.split_contents.keys.length
    assert_instance_of DateTime, rs.split_contents.keys[0]
    assert_equal "Available", rs.split_contents.values[0]
  end

  def test_evaluate_availability_adds_time
    rs = PairingOrganization::ReadSpreadsheet.new

    assert_equal "08:00:00 Not_Available", rs.generate_availability_time(nil, 1)
    assert_equal "12:00:00 Not_Available", rs.generate_availability_time(nil, 2)
    assert_equal "16:00:00 Available", rs.generate_availability_time("Available", 3)
    assert_equal "12:00:00 Booked", rs.generate_availability_time("Fred", 2)
  end

  def test_it_creates_ical_files
    rs = PairingOrganization::ReadSpreadsheet.new
    contents = rs.split_contents
    ical = PairingOrganization::CreateIcalFiles.new(contents)

    assert_instance_of PairingOrganization::CreateIcalFiles, ical
  end

  def test_it_createst_an_instance_of_ical
    rs = PairingOrganization::ReadSpreadsheet.new
    contents = rs.split_contents
    ical = PairingOrganization::CreateIcalFiles.new(contents)

    assert_instance_of Icalendar::Calendar, ical.cal
  end

  def test_it_saves_ical_file_to_temp
    contents = {DateTime.parse("2015-10-10 08:00:00") => "Available"}
    ical = PairingOrganization::CreateIcalFiles.new(contents)

    assert_equal true, File.exist?("./temp/scripted.ics")
  end
end
