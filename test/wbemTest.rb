$:.push("#{File.dirname(__FILE__)}/../lib")

require 'wbem'

server		= ''
username	= ''
password	= ''

begin
	include WBEM
	
	client = WBEMConnection.new("https://#{server}", [username, password], 'interop')
	
	t0 = Time.now
	
	client.default_namespace = 'root/ontap'
	
	puts "**** EnumerateClassNames"
	result  = client.EnumerateClassNames(:DeepInheritance => true)
	puts "**** DONE"
	
	result.each do |cn|
		puts "\tGetClass: #{cn.to_s}"
		klass = client.GetClass(cn)
		# puts client.last_reply
		puts "\t\tClass: #{klass.class.to_s}, Superclass: #{klass.superclass}"
		puts "\t\tProperties:"
		klass.properties.each do |k, v|
			puts "\t\t\t#{k} = #{v.value}"
		end
		puts "\t\tQualifiers:"
		klass.qualifiers.each do |k, v|
			puts "\t\t\t#{k}"
		end
		puts "\tDONE"
	end
	puts

	puts "**** EnumerateClasses"
	result2 = client.EnumerateClasses(:DeepInheritance => true)
	puts "**** DONE"
	puts
	
	puts "result.length = #{result.length}, result2.length = #{result2.length}"
	puts
		
	client.default_namespace = 'interop'
		
	pia = client.EnumerateInstanceNames('CIM_RegisteredProfile')
	pia.each do |inm|
		begin
			puts "instance name: (#{inm.class.to_s}) #{inm.to_s}"
			puts "\tnamespace =  #{inm.namespace}"
			puts "\tclass_name =  #{inm.classname}"
			
			#
			# Get the instance given its name.
			#
			inst = client.GetInstance(inm)
			puts "\tinstance: (#{inst.class.to_s}) #{inst.to_s}"

			#
			# Get the associator names for the instance.
			#
			ana = client.AssociatorNames(inm,
										:AssocClass		=> 'CIM_ReferencedProfile',
										:ResultClass	=> 'CIM_RegisteredProfile',
										:Role			=> "Dependent",
										:ResultRole		=> "Antecedent"
			)
			puts "\tana: #{ana.class.to_s}"
			ana.each { |an| puts "\t\t#{an.to_s}" }
			
			#
			# Get the associators for the instance.
			#
			aa = client.Associators(inm,
									:AssocClass		=> 'CIM_ReferencedProfile',
									:ResultClass	=> 'CIM_RegisteredProfile',
									:Role			=> "Dependent",
									:ResultRole		=> "Antecedent"
			)
			puts "\taa: #{aa.class.to_s}"
			aa.each { |a| puts "\t\t#{a.to_s}" }
			
			#
			# Get all of the reference names for the instance.
			#
			rna = client.ReferenceNames(inm)
			puts "\trna: #{rna.class.to_s}"
			rna.each do |rn|
				puts "\t\t#{rn.class.to_s}"
				puts "\t\t#{rn.to_s[0,80]}..."
				
				ri = client.GetInstance(rn, :LocalNamespacePath => rn.namespace)
				puts "\t\t\t#{ri.to_s[0,80]}..."
			end
			
			ra = client.References(inm)
			puts "\tra: #{ra.class.to_s}"
			ra.each { |r| puts "\t\t#{r.to_s[0,80]}..." }
			
			puts
		rescue Exception => ierr
			puts ierr.to_s
			puts ierr.backtrace.join("\n")
			puts
		end
	end
	
	t1 = Time.now
	puts
	puts "ET = #{t1-t0}"
	
rescue Exception => err
	puts err.to_s
	puts err.backtrace.join("\n")
end
