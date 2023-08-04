# coding: utf-8
require "ravensat"
require "nokogiri"
require "rufo"

module Swallow
  class Formatter
    def format(ast); end
  end

  class AUKFormatter < Formatter
    def format(ast)
      auk = ""
      ast.nodes.each do |node|
        auk << node.to_auk
      end
      formatter = Rufo::Formatter.new(auk)
      formatter.format
      formatter.result
    end
  end

  class CNFFormatter < Formatter
    def format(ast, ptable)
      cnf = Ravensat::InitialNode.new

      # Domain constraint
      ast.nodes.each do |node|
        node.prun(ptable)
      end

      # Domain execution
    # ast.nodes.find{|i|i.is_a? TimeslotInitializer}.timeslots.each do |node|
    #   tmp = node.domain_exec(ptable)
    #   cnf &= tmp unless tmp.is_a? Ravensat::InitialNode
    # end
      ast.nodes.each do |node|
        tmp = node.domain_exec(ptable)
        cnf &= tmp unless tmp.is_a? Ravensat::InitialNode
      end

      # Exactly One nurse
    # pvars = ptable.group_by{|i| i.nurse.name}.values.reject{|i| i.first.nurse.domain.include? DomainFrequency}

    # unless pvars.empty?
    #   cnf &= pvars.map do |e|
    #     Ravensat::Claw.alo e.map(&:value)
    #   end.reduce(:&)
    #   cnf &= pvars.map do |e|
    #     Ravensat::Claw.commander_amo e.map(&:value)
    #   end.reduce(:&)
    # end

    ##################
    #この先する必要があるところ
    ##################
    # Conflict Constraints
    ast.nodes.each do |node|
      cnf &= node.exec(ptable) if node.is_a? Constraint
    end

      cnf
    end
  end

  class CSVFormatter < Formatter
    def format(ast)
      csv = [] # CSV::Table
      ast.nodes.each do |node|
        csv.append [node.name] + node.domain_timeslot.period if node.domain_timeslot
      end
      # TODO: CSVクラスを使用することを検討
      csv.map(&:to_csv).reduce { |result, item| "#{result}#{item}\n" }.chomp
    end
  end

  class HTMLFormatter < Formatter
    # def slot_content(nurse, timeslot, nrs_periods)
    #   binding.irb
    #   return "日" if nrs_periods.include?([nurse, timeslot + "day"])
    #   return "準" if nrs_periods.include?([nurse, timeslot + "sem"])
    #   return "深" if nrs_periods.include?([nurse, timeslot + "ngt"])
    #   return "休"
    # end

    def format(ast)
      # TODO: Nokogiriを使用する
      # timeslot_constraint = ast.nodes.find{|node| node.is_a? TimeslotInitializer}.domain.constraints
      n_timeslots = []
      n_nurses = []
      c_nurses = []
      nrs_periods = []

      ast.nodes.each do |node|
        next unless node.is_a? Timeslot
        n_timeslots << node.name
      end
      ast.nodes.each do |node|
        next unless node.is_a? Nurse
        n_nurses << node.name
        nurse = node.name
        node.domain.constraints.first.timeslots.each do |timeslot|
          c_nurses = timeslot
          nrs_periods.append [nurse, c_nurses]
        end
      end

      root = Nokogiri::HTML::DocumentFragment.parse("")
      Nokogiri::HTML::Builder.with(root) do |doc|
        doc.link rel: "stylesheet", href: "https://maxcdn.bootstrapcdn.com/bootstrap/3.3.1/css/bootstrap.min.css"
        doc.div.nav.index do
          doc.h1 "Work Schedule"
          doc.table class: "table table-bordered" do
            doc.tr do
              doc.th nil
              n_timeslots.map { |ts| ts[/\d+/] }.uniq.sort.each do |timeslot|
                doc.th timeslot
              end
            end
            n_nurses.each do |nurse|
              doc.tr do
                doc.th nurse
                n_timeslots.map { |ts| ts[/\d+/] }.uniq.sort.each do |timeslot|
                  td = []
                  if nrs_periods.include?([nurse, timeslot + "day"])
                    td.append "日"
                  elsif nrs_periods.include?([nurse, timeslot + "sem"])
                    td.append "準"
                  elsif nrs_periods.include?([nurse, timeslot + "ngt"])
                    td.append "深"
                  else
                    td.append "休"
                  end
                  doc.td td.join("<br>"), id: "id_#{nurse}_#{timeslot}"
                end
              end
            end
          end
        end
      end
      CGI.unescapeHTML root.to_html
    end
  end
end