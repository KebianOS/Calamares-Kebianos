.PHONY: build clean install-local

# Ejecuta 'make build' para generar el .deb
build:
	cd calamares-settings-kebianos && \
	find . -exec touch {} + && \
	dpkg-buildpackage -us -uc -b

# Ejecuta 'make clean' para borrar los .deb, .changes y carpetas temporales
clean:
	cd calamares-settings-kebianos && dh clean
	rm -f *.deb *.buildinfo *.changes

# Ejecuta 'make install-local' para compilar e instalarlo en tu PC de una vez
install-local: build
	sudo apt install -y ./calamares-settings-kebianos_*.deb
