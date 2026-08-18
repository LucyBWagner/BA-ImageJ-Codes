
// Fiji ImageJ Macro: MASTER BATCH (Messung + Dead Cell Zählung)
// 1. Zählt alle Zellen, tote Zellen und lebende Zellen (speichert ein globales CSV).
// 2. Misst die Intensität (C1 & C2) NUR von den lebenden Zellen (speichert CSV pro Ordner).


minSize = 50;           
maxSize = 400;           
minCirc = 0.30;         
maxCirc = 0.80;          
blurSigma = 2;           
threshMethod = "Triangle"; 


mainDir = getDirectory("Wähle den HAUPT-ORDNER aus (z.B. '2 clean data' oder 'batch 1')");

setBatchMode(true);
print("\\Clear");
print("Starte MASTER-BATCH (Zählung + Messung in einem)...");

// Globale Zusammenfassung initialisieren
summaryFilePath = mainDir + "Dead_Cell_Summary.csv";
File.saveString("Ordner,Zellen Gesamt,Lebende Zellen,Tote Zellen,Tote Zellen (%)\n", summaryFilePath);

processFolder(mainDir);

print("-------------------------------------------------");
print("Fertig! Alle Messungen wurden lokal in den Ordnern gespeichert.");
print("Die globale Zusammenfassung der toten Zellen liegt unter: " + summaryFilePath);
setBatchMode(false);
showMessage("Fertig!", "Master-Batch abgeschlossen.\nDetails im Log-Fenster.");



// FUNKTION: Rekursive Suche nach Ordnern

function processFolder(folder) {
    list = getFileList(folder);
    hasImages = false;
    for (i = 0; i < list.length; i++) {
        if (endsWith(list[i], ".tif") || endsWith(list[i], ".TIF")) {
            hasImages = true; break;
        }
    }
    if (hasImages) {
        analyzeFolder(folder);
    } else {
        for (i = 0; i < list.length; i++) {
            if (endsWith(list[i], "/")) {
                processFolder(folder + list[i]);
            }
        }
    }
}


// FUNKTION: Analyse und Messung pro Ordner

function analyzeFolder(inputDir) {
    run("Clear Results");
    roiManager("reset");
    run("Set Measurements...", "area mean integrated shape display redirect=None decimal=3");
    
    list = getFileList(inputDir);
    
    folderTotal = 0;
    folderLiving = 0;
    folderDead = 0;
    
    for (i = 0; i < list.length; i++) {
        if (startsWith(list[i], "C1") && (endsWith(list[i], ".tif") || endsWith(list[i], ".TIF"))) {
            
            c1File = list[i];
            c2File = replace(c1File, "C1", "C2");
            c3File = replace(c1File, "C1", "C3"); 
            
            if (File.exists(inputDir + c2File) && File.exists(inputDir + c3File)) {
                
                open(inputDir + c1File); ch1Title = getTitle();
                open(inputDir + c2File); ch2Title = getTitle();
                open(inputDir + c3File); ch3Title = getTitle();
                
                // 1. Exklusions-Maske (C3)
                selectWindow(ch3Title);
                run("Duplicate...", "title=mask_c3");
                run("Enhance Contrast...", "saturated=0.3 normalize"); // Höchste Sensitivität für schwache C3
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
                
                // 3. ALLE Zellen finden (Gesamtzahl)
                roiManager("reset");
                selectWindow(masterTitle);
                run("Analyze Particles...", "size=" + minSize + "-" + maxSize + " pixel circularity=" + minCirc + "-" + maxCirc + " exclude add");
                
                totalInImage = roiManager("count");
                folderTotal = folderTotal + totalInImage;
                deadInImage = 0;
                
                // 4. Tote Zellen aussortieren (Schnelle Bulk-Methode)
                if (totalInImage > 0) {
                    selectWindow("mask_c3");
                    
                    // a) Zählen & Array bauen
                    deadCount = 0;
                    for (r = 0; r < totalInImage; r++) {
                        roiManager("select", r);
                        if (getValue("Mean") > 5) { deadCount++; }
                    }
                    
                    deadInImage = deadCount;
                    folderDead = folderDead + deadInImage;
                    folderLiving = folderLiving + (totalInImage - deadInImage);
                    
                    // b) Tote ROIs blitzschnell löschen
                    if (deadCount > 0) {
                        toDelete = newArray(deadCount);
                        idx = 0;
                        for (r = 0; r < totalInImage; r++) {
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
                
                // 5. Lebende Zellen in C1 und C2 MESSEN (für die Excel Liste)
                if (roiManager("count") > 0) {
                    selectWindow(ch1Title);
                    roiManager("Measure");
                    
                    selectWindow(ch2Title);
                    roiManager("Measure");
                }
                
                // Aufräumen
                selectWindow(masterTitle); close();
                selectWindow("mask_c3"); close();
                selectWindow(ch1Title); close();
                selectWindow(ch2Title); close();
                selectWindow(ch3Title); close();
            }
        }
    }
    
    // Ordnernamen extrahieren (z.B. "B2")
    dirNoSlash = substring(inputDir, 0, lengthOf(inputDir)-1);
    lastSlashIndex = lastIndexOf(dirNoSlash, "/");
    if (lastSlashIndex == -1) { lastSlashIndex = lastIndexOf(dirNoSlash, "\\"); }
    folderName = substring(dirNoSlash, lastSlashIndex + 1);
        
    // 6. CSV für MESSUNGEN im jeweiligen Ordner speichern
    if (nResults > 0) {
        saveAs("Results", inputDir + folderName + ".csv");
        print("-> Gemessen & Gespeichert: " + folderName + ".csv (in " + inputDir + ")");
    }
    
    // 7. ZÄHLUNG an globale Summary (Dead_Cell_Summary.csv) anhängen
    if (folderTotal > 0) {
        deadPercent = (folderDead / folderTotal) * 100;
        line = folderName + "," + folderTotal + "," + folderLiving + "," + folderDead + "," + deadPercent + "\n";
        File.append(line, summaryFilePath);
        print("   " + folderTotal + " Zellen (" + folderDead + " tot -> " + d2s(deadPercent, 1) + "%)");
    }
}
