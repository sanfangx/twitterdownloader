require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Check if target already exists
if project.targets.any? { |t| t.name == 'TwitterShareExtension' }
  puts "Target already exists."
  exit 0
end

# 1. Add the group and files
ext_group = project.main_group.find_subpath('TwitterShareExtension', true)
ext_group.set_source_tree('<group>')
ext_group.set_path('TwitterShareExtension')

swift_file = ext_group.new_reference('ShareViewController.swift')
plist_file = ext_group.new_reference('Info.plist')

# 2. Create the target
ext_target = project.new_target(:app_extension, 'TwitterShareExtension', :ios, '14.0')
ext_target.product_name = 'TwitterShareExtension'

# 3. Configure Build Settings
ext_target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = 'TwitterShareExtension/Info.plist'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.trollstore.twitterdownloader.TwitterShareExtension'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
  config.build_settings['DEVELOPMENT_TEAM'] = ''
  config.build_settings['CODE_SIGN_IDENTITY'] = ''
  config.build_settings['SKIP_INSTALL'] = 'YES'
end

# 4. Add file to compile sources
ext_target.source_build_phase.add_file_reference(swift_file)

# 5. Embed the extension in the main Runner app
runner_target = project.targets.find { |t| t.name == 'Runner' }

# Find or create "Embed Foundation Extensions" copy files phase
embed_phase = runner_target.copy_files_build_phases.find { |p| p.name == 'Embed App Extensions' }
unless embed_phase
  embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
  embed_phase.name = 'Embed App Extensions'
  embed_phase.symbol_dst_subfolder_spec = :plug_ins
  runner_target.build_phases << embed_phase
end

# Add the extension product to the embed phase
build_file = embed_phase.add_file_reference(ext_target.product_reference)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# 6. Add target dependency (Runner depends on Extension)
runner_target.add_dependency(ext_target)

project.save
puts "Successfully added TwitterShareExtension target!"
