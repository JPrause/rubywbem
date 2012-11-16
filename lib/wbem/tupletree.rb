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

# """
# tupletree - Convert XML DOM objects to and from tuple trees.

# DOM is the standard in-memory representation of XML documents, but it
# is very cumbersome for some types of processing where XML encodes
# object structures rather than text documents.  Direct mapping to Python
# classes may not be a good match either.

# tupletrees may be created from an in-memory DOM using
# dom_to_tupletree(), or from a string using xml_to_tupletree().

# Since the Python XML libraries deal mostly with Unicode strings they
# are also returned here.  If plain Strings are passed in they will be
# converted by xmldom.

# Each node of the tuple tree is a Python 4-tuple, corresponding to an
# XML Element (i.e. <tag>):

#   (NAME, ATTRS, CONTENTS, None)

# The NAME is the name of the element.

# The ATTRS are a name-value hash of element attributes.

# The CONTENTS is a list of child elements.

# The fourth element is reserved.
# """

require "nokogiri"

module WBEM

    def tupletree_to_dom(document, tree, parent=nil)
#    """Convert tupletree to an XML DOM tree within a document.
#    """
#    import types
        name, attrs, contents, junk = tree
    
        parent = document if parent.nil?
        elt = Element.new(name, parent)

        attrs.each { |key, val| elt.add_attribute(key, val) }
        contents.each do |child|
            if child.is_a? Array
                tupletree_to_dom(document, child, elt)
            else
                elt.add_text(child)
            end
        end
        return elt
    end

    def WBEM.dom_to_tupletree(node)
#     """Convert a DOM object to a pyRXP-style tuple tree.

#     Each element is a 4-tuple of (NAME, ATTRS, CONTENTS, None).

#     Very nice for processing complex nested trees.
#     """
        if node.node_type == LibXML::XML::Node::DOCUMENT_NODE
            # boring; pop down one level
            return dom_to_tupletree(node.child)
        end
        unless node.node_type == LibXML::XML::Node::ELEMENT_NODE
            raise TypeError, "node must be an element"
        end
        
        name = node.name
        attrs = {}
        contents = []

        node.children.each do |child|
            if child.node_type == LibXML::XML::Node::ELEMENT_NODE
                contents << dom_to_tupletree(child)
            elsif child.node_type == LibXML::XML::Node::TEXT_NODE
                unless child.content.kind_of?(String)
                    raise TypeError, "text node #{child} must be a string"
                end
                contents << child.content
            else
                raise RuntimeError, "can't handle #{child}"
            end
        end

        node.attributes.each { |a| attrs[a.name] = a.value }

        # XXX: Cannot yet handle comments, cdata, processing instructions and
        # other XML batshit.

        # it's so easy in retrospect!
        return [name, attrs, contents]
    end

    def WBEM.xml_to_tupletree(xml_string)
#    """Parse XML straight into tupletree."""
        return dom_to_tupletree(LibXML::XML::Document.string(xml_string))
    end

    def WBEM.tupletree_to_s(tt)
        "name: #{tt[0]}\nattributes: #{tt[1].to_a.collect {|a| "(#{a[0]} => #{a[1]})"}.join(", ") unless tt[1].nil?}\n tree: #{unless tt[2].nil?
if tt[2][0].is_a?(Array)
    tt[2].collect { |t| WBEM.tupletree_to_s(t) }.join
else
    WBEM.tupletree_to_s(tt[2])
end
end
 }"
    end
end

