# Licensing and corresponding sources

Mini Core is a distribution assembled from separately licensed components.
The repository's MIT license covers its custom Rust init and configuration scripts.
It does not relicense upstream binaries.

For the v0.1.0 binary image:

- `manifests/packages-v0.1.0.json` identifies every installed binary package.
- `manifests/sources-v0.1.0.json` identifies its exact source package/version and
  declared Built-Using/Static-Built-Using source dependencies.
- `manifests/source-files-v0.1.0.json` records the upstream archive locations,
  filenames, sizes and SHA-256 hashes.
- `Mini-Core-v0.1.0-Corresponding-Sources.tar` in the same release supplies the
  upstream `.dsc`, original tar files, and Debian patch/tar files for those versions.
  It also contains the verified signed Debian index metadata and public archive keyring.
- The matching custom Mini Core sources are in the Git tag `v0.1.0` and GitHub's
  automatically generated source archives for that tag.

The source files were checked against source indexes whose InRelease signatures
were verified using the Debian archive public keyring. Archive SHA-256 hashes were
then checked against those indexes. These checks establish source provenance; they
are not a security audit of the software.

Original copyright/license notices remain in `/usr/share/doc` inside the image.
If you redistribute or modify these binaries, preserve the relevant notices and
comply with each component's license, including applicable corresponding-source
and installation-information requirements. Do not assume that a link to an
upstream homepage alone replaces those obligations.
