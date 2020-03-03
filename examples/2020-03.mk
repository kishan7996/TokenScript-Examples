ifeq ($(TOKENSCRIPT_SCHEMA),)
TOKENSCRIPT_SCHEMA=http://tokenscript.org/2020/03/tokenscript.xsd
endif

ifeq ($(XMLSECTOOL),)
XMLSECTOOL=xmlsectool
endif

ifndef KEY
KEY=1
endif

SIGNATURE_ALGORITHM=rsa-sha256

help:
	# Needs a target, example: $$ make EntryToken.canonicalized.xml
	#
	# Let's say you have a TokenScript "EntryToken.xml"
	# - to validate and canonicalize, add 'canonicalized' in the filename
	@echo $$ make EntryToken.canonicalized.xml
	# - to sign, use tsml as file extension:
	@echo $$ make EntryToken.tsml

%.canonicalized.xml : %.xml
    # xmlsectool canonicalises automatically when needed, but leaving an xml:base attribute which creates trouble later.
    # xmlstarlet does it neatly
	# XML Canonicalization
	xmlstarlet c14n $^  > $@
    # xmlsectool validates too, albeit adding xml:base with breaks schema. Example:
    # JVMOPTS=-Djavax.xml.accessExternalDTD=all /opt/xmlsectool-2.0.0/xmlsectool.sh --validateSchema --xsd --schemaDirectory ../../schema --inFile $^
	# XML Validation
    # if INVALID, run validation again with xmllint to get meaningful error
    # then delete the canonicalized file
	mv $@ $@.TEST
	xmlstarlet val --xsd $(TOKENSCRIPT_SCHEMA) $@.TEST || xmllint --noout --schema $(TOKENSCRIPT_SCHEMA) $@.TEST && mv $@.TEST $@

%.tsml: %.canonicalized.xml
ifeq (,$(KEYPASSWORD))
	$(error KEYPASSWORD is not set)
endif
ifeq (,$(KEYSTORE))
	@echo ---------------- Keystore missing. Try this ----------------
	@echo $$ make KEYSTORE=shong.wang.p12 KEYPASSWORD=shong.wang KEYINFO='"Shong Wang"' $@
	@echo replace it with your .p12 file and your password
	rm $^
else
	$(XMLSECTOOL) --sign --keyInfoKeyName "$(KEYINFO)" --digest SHA-256 --signatureAlgorithm http://www.w3.org/2001/04/xmldsig-more#$(SIGNATURE_ALGORITHM) --inFile $^ --outFile $@ --keystore $(KEYSTORE) --keystoreType PKCS12 --key $(KEY) --keyPassword "$(KEYPASSWORD)" --signaturePosition LAST
	# removing the canonicalized created for validation
	rm $^
endif
