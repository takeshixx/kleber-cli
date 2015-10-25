PREFIX=/usr
BINDIR=$(PREFIX)/bin

install:
		install -dm755 $(DESTDIR)$(BINDIR)
		install -m755 kleber $(DESTDIR)$(BINDIR)/kleber
		touch ~/.kleberrc

deinstall:
		rm -f $(DESTDIR)$(BINDIR)/kleber
		test -e ~/.kleberrc && rm ~/.kleberrc
