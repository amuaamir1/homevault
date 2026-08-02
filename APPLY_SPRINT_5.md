# Apply Sprint 5 Patch

Run all commands from the complete HomeVault project, not from the patch folder.

```powershell
cd C:\Projects\homeVaultApp

git status
git add .
git commit -m "Complete Sprint 4 warranty center"
git switch -c feat/sprint-5-service-history
```

After extracting `homevault_sprint_5_patch.zip`, update the patch path if needed:

```powershell
$patch = "C:\Projects\homevault_sprint_5_patch"

Copy-Item "$patch\lib\*" ".\lib" -Recurse -Force
Copy-Item "$patch\test\*" ".\test" -Recurse -Force
Copy-Item "$patch\pubspec.yaml" ".\pubspec.yaml" -Force
Copy-Item "$patch\README.md" ".\README.md" -Force
Copy-Item "$patch\SPRINT_5.md" ".\SPRINT_5.md" -Force
```

Then run:

```powershell
flutter clean
Remove-Item -Recurse -Force .dart_tool -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run
```

After emulator or phone testing:

```powershell
git add .
git commit -m "Implement Sprint 5 service and maintenance history"
git push -u origin feat/sprint-5-service-history
```
