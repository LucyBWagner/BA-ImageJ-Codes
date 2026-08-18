
// 1. Ordner abfragen
inputDir = getDirectory("Wähle den Input-Ordner mit den Bildern");
outputDir = getDirectory("Wähle den Output-Ordner für die Ergebnisse");

// 2. Dialog für Einstellungen anzeigen
Dialog.create("Verarbeitungs-Optionen");
Dialog.addNumber("Background Subtraction Radius (Rolling Ball, 0 zum Deaktivieren):", 10);
Dialog.show();

rollingRadius = Dialog.getNumber();

// 4. Liste aller Bilder abrufen
list = getFileList(inputDir);

// 5. Batch-Modus aktivieren 
setBatchMode(true);

// 6. Schleife für alle unterstützten Bilder
for (i = 0; i < list.length; i++) {
    if (endsWith(list[i], ".tif") || endsWith(list[i], ".TIF") || endsWith(list[i], ".nd2") || endsWith(list[i], ".czi")) {
        
        path = inputDir + list[i];
        
        // Dateiname ohne Endung extrahieren für ein sauberes Speichern
        baseName = list[i];
        dotIndex = lastIndexOf(baseName, ".");
        if (dotIndex > 0) {
            baseName = substring(baseName, 0, dotIndex);
        }
        
        // --- BIO-FORMATS INITIALISIEREN ---
        run("Bio-Formats Macro Extensions");
        Ext.setId(path);
        Ext.getSeriesCount(seriesCount);
        
        print("Verarbeite Datei: " + list[i] + " (" + seriesCount + " Serie(n))");
        
        // Schleife über alle Series in der Datei
        for (s = 0; s < seriesCount; s++) {
            showProgress(s, seriesCount);
            
            // Serie auswählen und öffnen (vermeidet Dialoge und schont den RAM)
            Ext.setSeries(s);
            Ext.openImagePlus(path);
            imgTitle = getTitle();
            
            // --- A. Z-PROJEKTION (Maximum Intensity) ---
            run("Z Project...", "projection=[Max Intensity]");
            mipTitle = getTitle();
            
            // Original-Z-Stack schließen (spart enorm viel Arbeitsspeicher!)
            selectWindow(imgTitle);
            close(); 
            
            // --- B. KANÄLE TRENNEN ---
            run("Split Channels");
            
            ch1Title = "C1-" + mipTitle;
            ch2Title = "C2-" + mipTitle;
            ch3Title = "C3-" + mipTitle; // NEU
            
            // Suffix für Dateiname falls mehrere Series vorhanden sind
            seriesSuffix = "";
            if (seriesCount > 1) {
                seriesNum = s + 1;
                if (seriesNum < 10) {
                    seriesSuffix = "_s0" + seriesNum;
                } else {
                    seriesSuffix = "_s" + seriesNum;
                }
            }
            
            // --- C. BEARBEITUNG KANAL 1 ---
            if (isOpen(ch1Title)) {
                selectWindow(ch1Title);
                
                // Hintergrund-Subtraktion
                if (rollingRadius > 0) {
                    run("Subtract Background...", "rolling=" + rollingRadius);
                }
                
                // Speichern als TIFF
                saveAs("Tiff", outputDir + "C1_" + baseName + seriesSuffix + ".tif");
                close();
            }
            
            // --- D. BEARBEITUNG KANAL 2 ---
            if (isOpen(ch2Title)) {
                selectWindow(ch2Title);
                
                // Hintergrund-Subtraktion
                if (rollingRadius > 0) {
                    run("Subtract Background...", "rolling=" + rollingRadius);
                }
                
                // Speichern als TIFF
                saveAs("Tiff", outputDir + "C2_" + baseName + seriesSuffix + ".tif");
                close();
            }

            // --- E. BEARBEITUNG KANAL 3 ---
            if (isOpen(ch3Title)) {
                selectWindow(ch3Title);
                
                // Hintergrund-Subtraktion
                if (rollingRadius > 0) {
                    run("Subtract Background...", "rolling=" + rollingRadius);
                }
                
                // Speichern als TIFF
                saveAs("Tiff", outputDir + "C3_" + baseName + seriesSuffix + ".tif");
                close();
            }
        }
    }
}

setBatchMode(false);
showMessage("Fertig!", "Alle Bilder und Serien (inklusive Kanal 3) wurden erfolgreich verarbeitet, getrennt und gespeichert!");