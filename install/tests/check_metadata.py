import lxml.etree, os.path, sys

if len(sys.argv) != 2:
    raise Exception('Must pass 1 argument with filename of metadata file')

if not os.path.exists(sys.argv[1]):
    raise Exception('Metadata file %s does not exist' % sys.argv[1])

metadata = lxml.etree.parse(sys.argv[1])
md_root = metadata.getroot()
XMLNS_MD = '{urn:oasis:names:tc:SAML:2.0:metadata}'
for e in md_root.findall(XMLNS_MD + 'EntityDescriptor'):
    print(e.attrib)
