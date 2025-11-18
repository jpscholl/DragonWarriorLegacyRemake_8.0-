// Declare the global list
var/list/baseIconColors

// Wrap all assignments inside a proc
proc/InitializeIconBaseColors()
    baseIconColors = list(
        "Hero" = list(
            'dw3hero.dmi' = list(
                "Main" = rgb(0, 124, 255),
                "Accent" = rgb(255, 255, 255),
                "Eyes" = rgb(0, 124, 250),
                "Hair" = rgb(0, 124, 254)
            ),
            'dw2hero.dmi' = list(
                "Main" = rgb(240, 210, 180),
                "Accent" = rgb(10, 100, 200),
                "Eyes" = rgb(0, 100, 200),
                "Hair" = rgb(20, 20, 20)
            )
        ),
        "Wizard" = list(
            'dw3malewizard.dmi' = list(
                "Main" = rgb(0, 172, 64),
                "Accent" = rgb(255, 255, 255),
                "Eyes" = rgb(254, 254, 254),
                "Hair" = rgb(0, 172, 65)
            ),
            'dw2wizard.dmi' = list(
                "Main" = rgb(30, 160, 60),
                "Accent" = rgb(200, 200, 255),
                "Eyes" = rgb(255, 255, 255),
                "Hair" = rgb(40, 40, 80)
            )
        ),
        "Soldier" = list(
            'dw3guard.dmi' = list(
                "Main" = rgb(180, 180, 180),
                "Accent" = rgb(100, 100, 100),
                "Eyes" = rgb(255, 255, 255),
                "Hair" = rgb(60, 60, 60)
            ),
            'dw2soldier.dmi' = list(
                "Main" = rgb(160, 160, 160),
                "Accent" = rgb(80, 80, 80),
                "Eyes" = rgb(240, 240, 240),
                "Hair" = rgb(50, 50, 50)
            )
        )
    )