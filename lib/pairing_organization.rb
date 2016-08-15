require "rubygems"
require "bundler"
require "csv"
require "date"
require "time"
Bundler.require

module PairingOrganization

  YOUR_NAME = "Ryan Workman"

  class Runner
    def initialize
      DownloadSpreadsheet.new
      rs = ReadSpreadsheet.new
      CreateIcalFiles.new(rs.split_contents)
      clear_temp_folder
    end

    def clear_temp_folder
      temp_files = `ls temp`
      temp_files.split("\n").each do |file|
        `rm temp/#{file}` if file.include?(".csv")
      end
    end
  end

  class DownloadSpreadsheet
    def initialize
      download_google_docs
    end

    def download_google_docs
      `open 'https://docs.google.com/spreadsheet/ccc?key=1ZWrDpgiYKJGHypAy6B8JakUNmbWqEfMs9DpDnaMbi04&output=csv'`
      puts "Downloading Spreadsheet..."
      sleep(5)
      make_temp_directory unless temp_directory_exists?
      move_spreadsheet_to_temp
    end

    def make_temp_directory
      Dir.mkdir("temp")
    end

    def temp_directory_exists?
      `ls`.include?("temp")
    end

    def move_spreadsheet_to_temp
      new_filename = "#{Time.now.to_s[0..9]}.csv"
      rename_spreadsheet(new_filename)
      `mv ~/Downloads/#{new_filename} #{Dir.pwd}`
      `mv #{new_filename} temp/`
    end

    def rename_spreadsheet(filename)
      `mv ~/Downloads/"1606%2F1608 Pairing Schedule - Sheet1.csv" #{filename}`
    end
  end

  class ReadSpreadsheet
    attr_reader :raw_contents,
                :contents,
                :split_contents

    def initialize
      @raw_contents = read_csv_file
      @contents = get_my_information
      @split_contents = split_up_contents
    end

    def read_csv_file
      contents = CSV.open "temp/#{Time.now.to_s[0..9]}.csv"
      contents.read
    end

    def get_my_information
      raw_contents.each_with_index do |content, index|
        return raw_contents[index] if content[0] == YOUR_NAME
      end
    end

    def split_up_contents
      puts "#{contents[0]} has #{contents[2].to_i} available slots and has #{contents[3].to_i} bookings."
      contents.shift(4)
      booking_dates = generate_booking_dates
      day_number = 0
      counter = 1
      parse_through_contents(booking_dates, day_number, counter)
    end

    def parse_through_contents(booking_dates, day_num, counter)
      contents.reduce({}) do |result, time|
        time = generate_availability_time(time, counter)
        result = generate_split_dates_and_time(result, time, booking_dates[day_num])
        counter += 1
        if counter > 3
          counter = 1
          day_num += 1
        end
        result
      end
    end

    def generate_availability_time(time, counter)
      booking_time = evaluate_booking_time(counter)
      availability = evaluate_availability(time)
      "#{booking_time} #{availability}"
    end

    def evaluate_availability(time)
      return "Booked::#{time}" unless time.nil? || time == "Available"
      if time.nil?
        "Not_Available"
      else
        time
      end
    end

    def evaluate_booking_time(counter)
      if counter == 1
        "08:00:00"
      elsif counter == 2
        "12:00:00"
      elsif counter == 3
        "16:00:00"
      end
    end

    def generate_split_dates_and_time(result, time, booking_date)
      time = time.split(" ")
      date_and_time = generate_date_and_time(booking_date, time[0])
      unless time[1] == "Not_Available"
        result[date_and_time] = time[1]
      end
      result
    end

    def generate_date_and_time(date, time)
      raw_date_time = date.strftime("%Y-%m-%d") + " #{time}"
      DateTime.parse(raw_date_time)
    end

    def generate_booking_dates
      raw_booking_dates = raw_contents[1].compact
      raw_booking_dates.map do |booking_date|
        Time.parse(booking_date)
      end
    end
  end

  class CreateIcalFiles
    attr_reader :contents,
                :saved_events,
                :cal

    def initialize(contents)
      @contents = contents
      @saved_events = load_saved_contents
      @cal = Icalendar::Calendar.new
      make_events
      save_events
      import_events_to_ical
    end

    def make_events
      contents.length.times do |index|
        event = Icalendar::Event.new
        event.dtstart = contents.keys[index]
        event.duration = "P1H"
        event.summary = "Mod 1 Pairing: #{contents.values[index]}"
        cal.add_event(event)
      end
    end

    def save_events
      puts "Saving iCal events."
      if saved_events.nil?
        write_file(cal.to_ical + "X-WR-RELCALID")
      else
        write_file(update_events)
      end
    end

    def load_saved_contents
      return nil unless File.exist?("./temp/scripted.ics")
      cal_events = File.read("./temp/scripted.ics")
      Icalendar::Calendar.parse(cal_events).first
    end

    def update_events
      rewrite_updates
      saved_events.to_ical
    end

    def rewrite_updates
      cal.events.each do |event|
        if event_exists?(event)
          change_event_summary(event)
        else
          saved_events.add_event(event)
        end
      end
    end

    def change_event_summary(event)
      saved_events.events.each do |saved_event|
        saved_event.summary = event.summary if saved_event.dtstart.to_s == event.dtstart.to_s
      end
    end

    def event_exists?(event)
      saved_events.events.any? do |saved_event|
        saved_event.dtstart.to_s == event.dtstart.to_s
      end
    end

    def write_file(contents_to_save)
      File.open("./temp/scripted.ics", "w") do |file|
        file.write contents_to_save
      end
    end

    def import_events_to_ical
      `open temp/scripted.ics`
    end
  end
end

PairingOrganization::Runner.new
