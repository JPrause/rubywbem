#
# Copyright 2006, Red Hat, Inc
# Scott Seago <sseago@redhat.com>
#
# derived from pywbem, written by Tim Potter <tpot@hp.com>, Martin Pool <mbp@hp.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#   
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#

require "rubygems"
require "wbem/cim_obj"
require "wbem/cim_xml"
require "wbem/cim_http"
require "wbem/tupletree"
require "wbem/tupleparse"

#"""CIM-XML/HTTP operations.
#
#The WBEMConnection class opens a connection to a remote WBEM server.
#Across this you can run various CIM operations.  Each method of this
#object corresponds fairly directly to a single CIM method call.
#"""

module WBEM
    DEFAULT_NAMESPACE = 'root/cimv2'

    # TODO: Many methods have more parameters that aren't set yet.

    # helper functions for validating arguments

    def WBEM._check_classname(val)
        unless val.is_a?(String)
            raise TypeError, "string expected for classname, not #{val}"
        end
    end

    class CIMError < Exception
        #"""Raised when something bad happens.  The associated value is a
        #tuple of (error_code, description).  An error code of zero
        #indicates an XML parsing error in RubyWBEM."""
        attr :code
        def initialize(code)
            @code = code
        end    
    end

    class WBEMConnection
        #"""Class representing a client's connection to a WBEM server.
    
        #At the moment there is no persistent TCP connection; the
        #connectedness is only conceptual.
        
        #After creating a connection, various methods may be called on the
        #object, which causes a remote call to the server.  All these
        #operations take regular Ruby or cim_types values for parameters,
        #and return the same.  The caller should not need to know about
        #the XML encoding.  (It should be possible to use a different
        #transport below this layer without disturbing any clients.)
        
        #The connection remembers the XML for the last request and last
        #reply.  This may be useful in debugging: if a problem occurs, you
        #can examine the last_request and last_reply fields of the
        #connection.  These are the prettified request and response; the
        #real request is sent without indents so as not to corrupt whitespace.
        
        #The caller may also register callback functions which are passed
        #the request before it is sent, and the reply before it is
        #unpacked.
        #"""
    
        attr_reader :url, :creds, :x509, :last_request, :last_raw_request, :last_reply
		attr_accessor :default_namespace
        def initialize(url, creds = nil, default_namespace = DEFAULT_NAMESPACE,
                       x509 = nil)
            @url = url
            @creds = creds
            @x509 = x509
            @last_request = @last_reply = ''
            @default_namespace = default_namespace
        end
        
        def to_s
            "#{self.class}(#{self.url}, user=#{self.creds[0]})"
        end

        def imethodcall(methodname, params)
            #"""Make an intrinsic method call.

            #Returns a tupletree with a IRETURNVALUE element at the root.
            #A CIMError exception is thrown if there was an error parsing
            #the call response, or an ERROR element was returned.
            
            #The parameters are automatically converted to the right
            #CIM_XML objects.
            
            #In general clients should call one of the method-specific
            #methods of the connection, such as EnumerateInstanceNames,
            #etc."""
            
            # If a LocalNamespacePath wasn't specified, use the default one

            localnamespacepath = params.delete(:LocalNamespacePath)
            localnamespacepath = self.default_namespace if localnamespacepath.nil?

            # Create HTTP headers
            
            headers = ["CIMOperation: MethodCall",
                       "CIMMethod: #{methodname}",
                       WBEM.get_object_header(localnamespacepath)]

			req_doc = CIMDOC.new

            # Create parameter list
            plist = params.to_a.collect do |x|
                IPARAMVALUE.new(req_doc, x[0].to_s, WBEM.tocimxml(req_doc, x[1]))
            end
        
            # Build XML request
            
            req_xml = CIM.new(req_doc, MESSAGE.new(req_doc, SIMPLEREQ.new(req_doc, IMETHODCALL.new(req_doc, methodname,
                                                                        LOCALNAMESPACEPATH.new(req_doc, localnamespacepath.split("/").collect do |ns| 
                                                                                                   NAMESPACE.new(req_doc, ns) 
                                                                                               end
                                                                                               ),
                                                                        plist)),
                                          '1001', '1.0'),
                              '2.0', '2.0')
            
            @last_raw_request = req_xml.to_s
            @last_request = req_xml.to_s
            # Get XML response

            begin
                resp_xml = WBEM.wbem_request(self.url, @last_raw_request, self.creds, 
                                             headers, 0, self.x509)
            rescue AuthError =>
                raise
            rescue CIMHttpError => arg
                # Convert cim_http exceptions to CIMError exceptions
                raise CIMError.new(0), arg.to_s
            end
            ## TODO: Perhaps only compute this if it's required?  Should not be
            ## all that expensive.
            
            reply_dom = Nokogiri::XML::Document.parse(resp_xml)

            ## We want to not insert any newline characters, because
            ## they're already present and we don't want them duplicated.
			@last_reply = reply_dom.to_s
			@last_raw_reply = reply_dom.to_s
#            STDOUT << "response: #{@last_reply}\n"

            # Parse response
            tmptt = WBEM.dom_to_tupletree(reply_dom)
#            STDOUT << "tmp tt: #{WBEM.tupletree_to_s(tmptt)}\n"
            tt = WBEM.parse_cim(tmptt)

            if (tt[0] != "CIM")
                raise CIMError.new(0), "Expecting CIM element, got #{tt[0]}"
            end
            tt = tt[2]
        
            if (tt[0] != "MESSAGE")
                raise CIMError.new(0), "Expecting MESSAGE element, got #{tt[0]}"
            end
            tt = tt[2]

            if (tt.length != 1)
                raise CIMError.new(0), "Expecting one SIMPLERSP element: nelements: #{tt.length}"
            end
            if (tt[0][0] != "SIMPLERSP")
                raise CIMError.new(0), "Expecting one SIMPLERSP element, found #{tt[0][0]}"
            end
            tt = tt[0][2]
        
            if (tt[0] != "IMETHODRESPONSE")
                raise CIMError.new(0), "Expecting IMETHODRESPONSE element, got #{tt[0]}"
            end

            if (tt[1]["NAME"] != methodname)
                raise CIMError.new(0), "Expecting attribute NAME=#{methodname}, got #{tt[1]['NAME']}"
            end
            tt = tt[2]

            # At this point we either have a IRETURNVALUE, ERROR element
            # or None if there was no child nodes of the IMETHODRESPONSE
            # element.

            if (tt.nil?)
                return nil
            end
            if (tt[0] == "ERROR")
                code = tt[1]['CODE'].to_i
                if tt[1].has_key?("DESCRIPTION")
                    raise CIMError.new(code), tt[1]["DESCRIPTION"]
                end

                raise CIMError.new(code), "Error code #{tt[1]['CODE']}"
                
                if (tt[0] != "IRETURNVALUE")
                    raise CIMError,new(0), "Expecting IRETURNVALUE element, got #{tt[0]}"
                end
            end
            return tt
        end
        
		# TODO: still needs to be changed for Nokogiri.
        def methodcall(methodname, localobject, params)
            #"""Make an extrinsic method call.
            
            #Returns a tupletree with a RETURNVALUE element at the root.
            #A CIMError exception is thrown if there was an error parsing
            #the call response, or an ERROR element was returned.
            
            #The parameters are automatically converted to the right
            #CIM_XML objects."""
            
            # Create HTTP headers
            
            headers = ["CIMOperation: MethodCall",
                       "CIMMethod: #{methodname}",
                       WBEM.get_object_header(localobject)]
            # Create parameter list

            
            plist = params.to_a.collect do |x|
                PARAMVALUE.new(x[0].to_s, WBEM.tocimxml(x[1], true), WBEM.cimtype(x[1]))
            end

            # Build XML request

            req_xml = CIM.new(MESSAGE.new(SIMPLEREQ.new(METHODCALL.new(methodname,
                                                                       localobject.tocimxml(),
                                                                       plist)),
                                          '1001', '1.0'),
                              '2.0', '2.0')

            @last_raw_request = ""
            @last_request = ""
            req_xml.write(@last_raw_request)
            req_xml.write(@last_request, 2)

            # Get XML response

            begin
                resp_xml = WBEM.wbem_request(self.url, @last_raw_request, self.creds, 
                                             headers)
            rescue CIMHttpError => arg
                # Convert cim_http exceptions to CIMError exceptions
                raise CIMError.new(0), arg.to_s
            end

            @last_reply = resp_xml

            tt = WBEM.parse_cim(WBEM.xml_to_tupletree(resp_xml))

            if (tt[0] != "CIM")
                raise CIMError.new(0), "Expecting CIM element, got #{tt[0]}"
            end
            tt = tt[2]
        
            if (tt[0] != "MESSAGE")
                raise CIMError.new(0), "Expecting MESSAGE element, got #{tt[0]}"
            end
            tt = tt[2]

            if (tt.length != 1 or tt[0][0] != "SIMPLERSP")
                raise CIMError.new(0), "Expecting one SIMPLERSP element"
            end
            tt = tt[0][2]
        
            if (tt[0] != "METHODRESPONSE")
                raise CIMError.new(0), "Expecting METHODRESPONSE element, got #{tt[0]}"
            end

            if (tt[1]["NAME"] != methodname)
                raise CIMError.new(0), "Expecting attribute NAME=#{methodname}, got #{tt[1]['NAME']}"
            end
            tt = tt[2]

            # At this point we have an optional RETURNVALUE and zero or more PARAMVALUE
            # elements representing output parameters.
            if (!tt.empty? and tt[0][0] == "ERROR")
                code = tt[0][1]["CODE"].to_i
                if tt[0][1].has_key?("DESCRIPTION")
                    raise CIMError.new(code), tt[0][1]['DESCRIPTION']
                end
                raise CIMError.new(code), "Error code #{tt[0][1]['CODE']}"
            end

            return tt
        end

        #
        # Instance provider API
        # 
        def EnumerateInstanceNames(className, params = {})
            #"""Enumerate instance names of a given classname.  Returns a
            #list of CIMInstanceName objects."""
            result = self.imethodcall("EnumerateInstanceNames",
                                      params.merge(Hash[:ClassName => CIMClassName.new(className)]))

            return result[2] unless result.nil?
            return []
        end

        def EnumerateInstances(className, params = {})
            #"""Enumerate instances of a given classname.  Returns a list
            #of CIMInstance objects."""

            result = self.imethodcall('EnumerateInstances',
                                      params.merge(Hash[:ClassName => CIMClassName.new(className)]))
            return result[2] unless result.nil?
            return []
        end

        def GetInstance(instancename, params = {})
            #"""Fetch an instance given by instancename.  Returns a
            #CIMInstance object."""
            
            # Strip off host and namespace to make this a "local" object
            iname = instancename.clone
            iname.host = nil
            iname.namespace = nil

            result = self.imethodcall("GetInstance",
                                      params.merge(Hash[:InstanceName => iname]))
            return result[2][0]
        end

        def DeleteInstance(instancename, params = {})
            #"""Delete the instance given by instancename."""

            # Strip off host and namespace to make this a "local" object
            iname = instancename.clone
            iname.host = nil
            iname.namespace = nil

            self.imethodcall("DeleteInstance",
                             params.merge(Hash[:InstanceName => iname]))
        end

        def CreateInstance(newinstance, params = {})
            #"""Create an instance.  Returns the name for the instance."""

            # Strip off path to avoid producing a VALUE.NAMEDINSTANCE
            # element instead of an INSTANCE element.

            instance = newinstance.clone
            instance.path = nil

            result = self.imethodcall("CreateInstance",
                                      params.merge(Hash[:NewInstance => instance]))
            return result[2][0]
        end

        def ModifyInstance(modifiedinstance, params = {})
            #"""Modify properties of a named instance."""
            # last arg is hash

            if modifiedinstance.path.nil?
                raise ArgumentError, 'modifiedinstance parameter must have path attribute set'
            end
        
            return self.imethodcall("ModifyInstance",
                                    params.merge(Hash[:ModifiedInstance => modifiedinstance]))
        end

        #
        # Schema management API
        #
        
        def EnumerateClassNames(params = {})
            #"""Return a list of CIM class names. Names are returned as strings."""
        
            result = self.imethodcall("EnumerateClassNames",
                                      params)
            
            return [] if result.nil?
            return result[2].collect { |x| x.classname}
        end
    
        def EnumerateClasses(params = {})
            #"""Return a list of CIM class objects."""

            result = self.imethodcall("EnumerateClasses",
                                      params)

            return [] if result.nil?
        
            return result[2]
        end

        def GetClass(className, params = {})
            #"""Return a CIMClass representing the named class."""
            
            result = self.imethodcall("GetClass",
                                      params.merge(Hash[:ClassName => CIMClassName.new(className)]))
            
            return result[2][0]
        end
        
        def DeleteClass(className, params = {})
            #"""Delete a class by class name."""

            # UNSUPPORTED (but actually works)

            self.imethodcall("DeleteClass",
                             params.merge(Hash[:ClassName => CIMClassName.new(className)]))
        end

        def ModifyClass(modifiedClass, params = {})
            #"""Modify a CIM class."""

            # UNSUPPORTED

            self.imethodcall('ModifyClass',
                             params.merge(Hash[:ModifiedClass => modifiedClass]))
        end

        def CreateClass(newClass, params = {})
            #"""Create a CIM class."""

            # UNSUPPORTED

            self.imethodcall('CreateClass',
                             params.merge(Hash[:NewClass => newClass]))
        end
        #
        # Association provider API
        # 
        
        def _add_objectname_param(params, object)
            #"""Add an object name (either a class name or an instance
            #name) to a dictionary of parameter names."""
            
            if (object.is_a?(CIMClassName) or object.is_a?(CIMInstanceName))
                params[:ObjectName] = object
            elsif (object.is_a?(String))
                params[:ObjectName] = CIMClassName.new(object)
            else
                raise TypeError, "Expecting a classname, CIMClassName or CIMInstanceName object"
            end
            return params
        end
        
        def _map_association_params(params = {})
            #"""Convert various convenience parameters and types into their
            #correct form for passing to the imethodcall() function."""
            
            # ResultClass and Role parameters that are strings should be
            # mapped to CIMClassName objects.
            
            if (params.has_key?(:ResultClass) and params[:ResultClass].is_a?(String))
                params[:ResultClass] = CIMClassName.new(params[:ResultClass])
            end
            if (params.has_key?("AssocClass") and params["AssocClass"].is_a?(String))
                params[:AssocClass] = CIMClassName.new(params[:AssocClass])
            end
            return params
        end

        def Associators(object_name, params = {})
            #"""Enumerate CIM classes or instances that are associated to a
            #particular source CIM Object.  Pass a keyword parameter of
            #'ClassName' to return associators for a CIM class, pass
            #'InstanceName' to return the associators for a CIM instance."""
            
            params = self._map_association_params(params)
            params = self._add_objectname_param(params, object_name)
            
            result = self.imethodcall("Associators",
                                      params)
            
            return [] if result.nil?
            return result[2].collect { |x| x[2]}
        end

        def AssociatorNames(object_name, params = {})
            #"""Enumerate the names of CIM classes or instances that are
            #associated to a particular source CIM Object.  Pass a keyword
            #parameter of 'ClassName' to return associators for a CIM
            #class, pass 'InstanceName' to return the associators for a CIM
            #instance.  Returns a list of CIMInstanceName objects with the
            #host and namespace attributes set."""
            
            params = self._map_association_params(params)
            params = self._add_objectname_param(params, object_name)
            
            result = self.imethodcall("AssociatorNames",
                                      params)
            return [] if result.nil?
            return result[2].collect { |x| x[2]}
        end
        
        def References(object_name, params = {})
            #"""Enumerate the association objects that refer to a
            #particular target CIM class or instance.  Pass a keyword
            #parameter of 'ClassName' to return associators for a CIM
            #class, pass 'InstanceName' to return the associators for a CIM
            #instance."""
            
            params = self._map_association_params(params)
            params = self._add_objectname_param(params, object_name)
            
            result = self.imethodcall("References",
                                      params)
            return [] if result.nil?
            return result[2].collect { |x| x[2]}
        end
        
        def ReferenceNames(object_name, params = {})
            #"""Enumerate the name of association objects that refer to a
            #particular target CIM class or instance.  Pass a keyword
            #parameter of 'ClassName' to return associators for a CIM
            #class, pass 'InstanceName' to return the associators for a CIM
            #instance."""
            
            params = self._map_association_params(params)
            params = self._add_objectname_param(params, object_name)
            
            result = self.imethodcall("ReferenceNames",
                                      params)
            return [] if result.nil?
            return result[2].collect { |x| x[2]}
        end
        
        #
        # Method provider API
        #
        
        def InvokeMethod(methodname, objectname, params = {})
            
            obj = objectname.clone
            
            if (obj.is_a?(String))
                obj = CIMLocalClassPath.new(self.default_namespace, obj)
            end

            if obj.is_a?(CIMInstanceName) and obj.namespace.nil?
                obj.namespace = DEFAULT_NAMESPACE
            end

            result = self.methodcall(methodname, obj, params)
            
            # Convert the RETURNVALUE into a Ruby object
            if (!result.empty? and result[0][0] == "RETURNVALUE")
                returnvalue = tocimobj(result[0][1]["PARAMTYPE"],
                                       result[0][2])
                
                # Convert output parameters into a dictionary of Python
                # objects.
                
                output_params = {}
                
                result[1..-1].each do |p|
                    output_params[p[0]] = tocimobj(p[1], p[2])
                end
                return returnvalue, output_params
            else
                return nil, {}
            end
        end
    end
end
