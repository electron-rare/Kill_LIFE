sch = Schematic('hardware/mon_schéma.kicad_sch')
sch.components[0].value = "10k"
sch.save('hardware/mon_schéma_modifié.kicad_sch')

