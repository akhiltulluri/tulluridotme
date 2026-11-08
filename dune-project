(lang dune 3.18)

(name tulluridotme)

(generate_opam_files)

(authors "Akhil Tulluri")

(maintainers "Akhil Tulluri")

(license MIT)

(package
 (name tulluridotme)
 (synopsis "Personal site of Akhil Tulluri, built with YOCaml")
 (allow_empty)
 (depends
  (ocaml
   (>= 5.1.1))
  (yocaml
   (>= 3.0.0))
  yocaml_unix
  yocaml_yaml
  yocaml_cmarkit
  yocaml_jingoo
  yocaml_syndication
  cmarkit))
