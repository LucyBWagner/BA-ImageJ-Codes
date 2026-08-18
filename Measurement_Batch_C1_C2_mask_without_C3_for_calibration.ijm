
// Zell-Filter (Analyze Particles):
minSize = 50;           
maxSize = 400;           
minCirc = 0.30;        
maxCirc = 0.80;          

// Weichzeichner-Einstellung:
blurSigma = 2;           // Sigma für den Gaussian Blur (leichtes Weichzeichnen)

// Schwellenwert-Methode (Threshold)
threshMethod = "Triangle"; 


// Hauptordner abfragen 
mainDir = getDirectory("Wähle den HAUPT-ORDNER aus (z.B. '2 clean data' oder 'batch 1')");

setBatchMode(true);
print("\\Clear");
print("Starte automatische Batch-Verarbeitung...");

// Starte den Durchlauf 
processFolder(mainDir);

setBatchMode(false);
showMessage("Fertig!", "Alle Ordner wurden verarbeitet und die Ergebnisse wurden als CSV gespeichert.\n\nSiehe Log-Fenster für Details.");



// FUNKTION: Sucht nach Bildern oder weiteren Unterordnern

function processFolder(folder) {
    list = getFileList(folder);
    hasImages = false;
    
    // Prüfen, ob dieser Ordner Bilder hat
    for (i = 0; i < list.length; i++) {
        if (endsWith(list[i], ".tif") || endsWith(list[i], ".TIF")) {
            hasImages = true;
            break;
        }
    }
    
    if (hasImages) {
        analyzeFolder(folder);
    } else {
        // Keine Bilder? Dann suche in allen Unterordnern weiter 
        for (i = 0; i < list.length; i++) {
            if (endsWith(list[i], "/")) {
                processFolder(folder + list[i]);
            }
        }
    }
}


// FUNKTION: Führt die eigentliche Messung durch

function analyzeFolder(inputDir) {
    run("Clear Results");
    roiManager("reset");
    run("Set Measurements...", "area mean integrated shape display redirect=None decimal=3");
    
    list = getFileList(inputDir);
    
    for (i = 0; i < list.length; i++) {
        // Sucht gezielt nach C1 (Startpunkt für ein Trio)
        if (startsWith(list[i], "C1") && (endsWith(list[i], ".tif") || endsWith(list[i], ".TIF"))) {
            
            c1File = list[i];
            c2File = replace(c1File, "C1", "C2");
            c3File = replace(c1File, "C1", "C3"); 
            
            // Nur messen, wenn C2 und C3 auch wirklich existieren!
            if (File.exists(inputDir + c2File) && File.exists(inputDir + c3File)) {
                
                open(inputDir + c1File); ch1Title = getTitle();
                open(inputDir + c2File); ch2Title = getTitle();
                open(inputDir + c3File); ch3Title = getTitle();
                
                // 1. Exklusions-Maske (C3)
                selectWindow(ch3Title);
                run("Duplicate...", "title=mask_c3");
                run("Enhance Contrast...", "saturated=0.3 normalize"); // 0.3 für hohe Sensitivität
                run("Gaussian Blur...", "sigma=" + blurSigma); 
                setAutoThreshold(threshMethod + " dark");
                setOption("BlackBackground", true);
                run("Convert to Mask");
                
                // 2. Master-Maske (C1+C2)
                imageCalculator("Add create", ch1Title, ch2Title);
                masterTitle = getTitle();
                
                selectWindow(masterTitle);
                run("Enhance Contrast...", "saturated=0.1 normalize");
                run("Gaussian Blur...", "sigma=" + blurSigma); 
                setAutoThreshold(threshMethod + " dark");
                setOption("BlackBackground", true);
                run("Convert to Mask");
                
                roiManager("reset");
                
                // 3. ALLE echten Zellen finden (VOR der toten Sortierung)
                selectWindow(masterTitle);
                run("Analyze Particles...", "size=" + minSize + "-" + maxSize + " pixel circularity=" + minCirc + "-" + maxCirc + " exclude add");
                
                // 4. Tote Zellen aussortieren 
                totalRois = roiManager("count");
                if (totalRois > 0) {
                    selectWindow("mask_c3");
                    
                    // Erster Durchlauf: Zählen wie viele gelöscht werden müssen
                    deadCount = 0;
                    for (r = 0; r < totalRois; r++) {
                        roiManager("select", r);
                        if (getValue("Mean") > 5) { deadCount++; }
                    }
                    
                    // Zweiter Durchlauf: Alle toten ROIs sammeln und löschen
                    if (deadCount > 0) {
                        toDelete = newArray(deadCount);
                        idx = 0;
                        for (r = 0; r < totalRois; r++) {
                            roiManager("select", r);
                            if (getValue("Mean") > 5) {
                                toDelete[idx] = r;
                                idx++;
                            }
                        }
                        roiManager("select", toDelete);
                        roiManager("Delete");
                    }
                }
                
                // 5. Messen in C1 und C2
                if (roiManager("count") > 0) {
                    selectWindow(ch1Title);
                    roiManager("Measure");
                    
                    selectWindow(ch2Title);
                    roiManager("Measure");
                }
                
                // Aufräumen pro Bild
                selectWindow(masterTitle); close();
                selectWindow("mask_c3"); close();
                selectWindow(ch1Title); close();
                selectWindow(ch2Title); close();
                selectWindow(ch3Title); close();
            }
        }
    }
    
    // 6. CSV Speichern, falls es Ergebnisse gab
    if (nResults > 0) {
        // Ordnernamen intelligent extrahieren 
        dirNoSlash = substring(inputDir, 0, lengthOf(inputDir)-1);
        lastSlashIndex = lastIndexOf(dirNoSlash, "/");
        if (lastSlashIndex == -1) {
            lastSlashIndex = lastIndexOf(dirNoSlash, "\\"); 
        }
        folderName = substring(dirNoSlash, lastSlashIndex + 1);
        
        saveAs("Results", inputDir + folderName + ".csv");
        print("-> Gemessen & Gespeichert: " + folderName + ".csv (in " + inputDir + ")");
    }
}
