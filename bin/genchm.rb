#!/bin/ruby

require 'klib'
require 'optparse'

class Project
	attr_accessor :source_html_dir
	attr_accessor :default_topic
	attr_accessor :compiled_file
	attr_accessor :project_file
	attr_accessor :contents_file
	attr_accessor :index_file
	attr_accessor :language
	attr_accessor :title
	attr_accessor :files
	
	def initialize(title, source_dir, index_html, chm_file)
		@source_html_dir = source_dir
		@default_topic = index_html
		@compiled_file = chm_file
		@title = title
		@project_file = 'default_project.hhp'
		@contents_file = 'default_contents.hhc'
		@index_file = 'default_index.hhk'
		@language = '0x804'
		@files = Array.new
	end

	def find_default_topic
		if source_html_dir
			index_html = Dir.glob(File.join(Env.unixpath(source_html_dir), '**/index.htm?')).sort {|x,y| File.filename_compare(x,y)}.first
			if index_html
				relative_name = File.relative_path(source_html_dir, index_html)
				return File.join(File.basename(source_html_dir), relative_name)
			end
		end
		return nil
	end
	
	def verify_arguments
		if not source_html_dir or not Dir.exist?(source_html_dir) 
			return false
		end
		
		if not default_topic
			@default_topic = find_default_topic
		end
		
		if not compiled_file
			@compiled_file = File.basename(source_html_dir) + '.chm'
		end
		
		if not title
			@title = File.basename(source_html_dir)
		end
		
		return true
	end
	
	def fullpath(filename)
		return File.join(File.expand_path(File.join(source_html_dir, '..')), filename)
	end
	
	def gen_project_file
		f = File.new(fullpath(project_file), "w")
		f.puts '[OPTIONS]'
		f.puts 'Compatibility=1.1 or later'
		f.puts "Compiled file=#{compiled_file}"
		f.puts "Default topic=#{default_topic}"
		f.puts "Contents file=#{contents_file}"
		f.puts "Index file=#{index_file}"
		f.puts "Title=#{title}"
		f.puts "Language=#{language}"
		f.puts 'Display compile progress=Yes'
		
		f.puts
		f.puts '[FILES]'
		go(File.expand_path(source_html_dir), f, fn_proc = :proc_file_item, false)
		f.close
	end
	
	def gen_content_file
		f = File.new(fullpath(contents_file), "w")
		f.puts '<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">'
		f.puts '<HTML><HEAD><meta name="GENERATOR" content="Microsoft&reg; HTML Help Workshop 4.1">'
		f.puts '<!-- Sitemap 1.0 -->'
		f.puts '</HEAD><BODY><OBJECT type="text/site properties"><param name="ImageType" value="Folder"></OBJECT><UL>'
		go(source_html_dir, f, fn_proc = :proc_content_item, true)
		f.puts '</UL></BODY></HTML>'
		f.close
	end
	
	def gen_index_file
		f = File.new(fullpath(index_file), "w")
		f.puts '<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">'
		f.puts '<HTML><HEAD><meta name="GENERATOR" content="Microsoft&reg; HTML Help Workshop 4.1">'
		f.puts '<!-- Sitemap 1.0 -->'
		f.puts '</HEAD><BODY><UL>'
		go(source_html_dir, f, fn_proc = :proc_key_item, false)
		f.puts '</UL></BODY></HTML>'
		f.close
	end
	
	def chm_object(name, addr = nil, image = nil)
		str = '<OBJECT type="text/sitemap">'
		str = str + "<param name=\"Name\" value=\"#{name}\">" if name.to_s.length > 0
		str = str + "<param name=\"Local\" value=\"#{addr}\">" if addr.to_s.length > 0
		str = str + "<param name=\"ImageNumber\" value=\"#{image}\">" if image.to_s.length > 0
		str = str + '</OBJECT>'
		return str
	end
	
	def has_html_files?(path)
		return Dir.glob(File.join(Env.unixpath(path), '*.htm*')).length > 0
	end
	
	def go(root, outfile, fn_proc, group_tag)
		self.send(fn_proc, root, outfile)
		
		has_group = group_tag && has_html_files?(root)
		outfile.puts '<UL>' if has_group

		Dir.entries(root).each {|f|
			if not [ '.', '..' ].include?(f)
				path = File.join(root, f)
				if File.directory?(path)
					go(path, outfile, fn_proc, group_tag)
				else
					self.send(fn_proc, path, outfile)
				end
			end
		}
		outfile.puts '</UL>' if has_group
	end
	
	def relative_url(root, path)
		root = Env.unixpath(root)
		path = Env.unixpath(path)
		if path.start_with?(root)
			File.join(File.basename(root), path[root.length..-1])
		else
			return path
		end
	end
	
	def html_file?(path)
		case File.extname(path).downcase
		when '.html'
			return true
		when '.htm'
			return true
		else
			return false
		end
	end
	
	def proc_file_item(path, file)
		if not File.directory?(path)
			file.puts Env.dospath(path)
		end
	end
	
	def proc_key_item(path, file)
		if not File.directory?(path) and html_file?(path)
			file.puts "<LI>#{chm_object(File.basename_noext(path), relative_url(source_html_dir, path))}"
		end
	end

	def matched_html(path)
		# check if index.html exist
		index_html = Dir.glob(File.join(Env.unixpath(path), 'index.htm?')).sort.first
		return index_html if index_html != nil

		# check if there is a html file in same name
		sname_html = File.join(File.dirname(path), File.basename(path) + '.html')
		return sname_html if File.exist?(sname_html)

		return nil
	end
	
	def matched_dir(file)
		if ['index.html', 'index.htm'].include?(File.basename(file).downcase)
			# for index html file, returns its parent directory name
			return File.dirname(File.expand_path(file))
		else
			# for other html file, if there is a directory has the same basename then it matches
			dir = File.join(File.dirname(file), File.basename_noext(file))
			if Dir.exist?(dir)
				return dir
			else
				return nil
			end
		end
	end
	
	def proc_content_item(path, file)
		if File.directory?(path) and has_html_files?(path)
			matched_html_file = matched_html(path)
			if not matched_html_file
				file.puts "<LI>#{chm_object(File.basename(path))}"
			else
				file.puts "<LI>#{chm_object(File.basename_noext(path), relative_url(source_html_dir, matched_html_file))}"
			end
		elsif html_file?(path)
			if not matched_dir(path)
				file.puts "<LI>#{chm_object(File.basename_noext(path), relative_url(source_html_dir, path))}"
			end
		end
	end
end

def parse_args(args)
	options = {}
	options[:title] = nil
	options[:source_dir] = nil
	options[:index] = nil
	options[:chm_file] = nil
	
	opt_parser = OptionParser.new do |opts|
		opts.banner = "Usage: #{Env.command_name} [OPTIONS]"
		opts.separator ""
		opts.separator "Options:"
		
		opts.on("-s", "--source DIRECTORY", "source html directory") do |dir|
			options[:source_dir] = dir
		end
		
		opts.on("-t", "--title TITLE", "specify the title") do |title|
			options[:title] = title
		end

		opts.on("-i", "--index INDEX", "specify the html index file") do |index|
			options[:index] = index
		end

		opts.on("-o", "--output CHM", "specify the destination CHM file") do |chm|
			options[:chm_file] = chm
		end

		opts.on_tail("-h", "--help", "Show this message") do
			puts opts
			exit
		end
	end

	opt_parser.parse!(args)
	options[:parser] = opt_parser
	return options
end

def main
	options = parse_args(ARGV)
	prj = Project.new(options[:title], options[:source_dir], options[:index], options[:chm_file])
	if not prj.verify_arguments
		puts options[:parser]
	else
		prj.gen_project_file
		prj.gen_content_file
		prj.gen_index_file
		
		cur_dir = Dir.getwd
		working_dir = File.expand_path(File.join(prj.source_html_dir, '..'))
		Dir.chdir(working_dir)
		run("hhc #{prj.project_file}")
		Dir.chdir(cur_dir)
	end
end

main
