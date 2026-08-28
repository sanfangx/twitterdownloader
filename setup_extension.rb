require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Check if target already exists
if project.targets.any? { |t| t.name == 'TwitterShareExtension' }
  puts "Target already exists."
  exit 0
end

runner_target = project.targets.find { |t| t.name == 'Runner' }

# Get Runner's deployment target so the extension matches
runner_deployment_target = nil
runner_target.build_configurations.each do |config|
  if config.name == 'Release'
    runner_deployment_target = config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
    break
  end
end
runner_deployment_target ||= '15.0'
puts "Using deployment target: #{runner_deployment_target}"

# 1. Add the group and files
ext_group = project.main_group.find_subpath('TwitterShareExtension', true)
ext_group.set_source_tree('<group>')
ext_group.set_path('TwitterShareExtension')

swift_file = ext_group.new_reference('ShareViewController.swift')
plist_file = ext_group.new_reference('Info.plist')

# 2. Create the target
ext_target = project.new_target(:app_extension, 'TwitterShareExtension', :ios, runner_deployment_target)
ext_target.product_name = 'TwitterShareExtension'

# 3. Configure Build Settings
ext_target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = 'TwitterShareExtension/Info.plist'
  config.build_settings['PRODUCT_NAME'] = 'TwitterShareExtension'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.trollstore.twitterdownloader.TwitterShareExtension'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = runner_deployment_target
  config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
  config.build_settings['DEVELOPMENT_TEAM'] = ''
  config.build_settings['CODE_SIGN_IDENTITY'] = ''
  config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
  config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
  config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = ''
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
end

# 4. Add source file to compile
ext_target.source_build_phase.add_file_reference(swift_file)

# 5. Add target dependency (Runner depends on Extension)
runner_target.add_dependency(ext_target)

# 6. Create "Embed App Extensions" phase and insert AFTER "Copy Bundle Resources"
embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
embed_phase.name = 'Embed App Extensions'
embed_phase.symbol_dst_subfolder_spec = :plug_ins

# Find the right insertion point: after "Copy Bundle Resources", before "Thin Binary"
copy_resources_index = runner_target.build_phases.find_index { |p|
  p.is_a?(Xcodeproj::Project::Object::PBXResourcesBuildPhase)
}

if copy_resources_index
  runner_target.build_phases.insert(copy_resources_index + 1, embed_phase)
  puts "Inserted Embed App Extensions after Copy Bundle Resources (index #{copy_resources_index + 1})"
else
  # Fallback: insert before Thin Binary
  thin_index = runner_target.build_phases.find_index { |p|
    p.respond_to?(:name) && p.name == 'Thin Binary'
  }
  if thin_index
    runner_target.build_phases.insert(thin_index, embed_phase)
    puts "Inserted Embed App Extensions before Thin Binary (index #{thin_index})"
  else
    runner_target.build_phases << embed_phase
    puts "Appended Embed App Extensions to end"
  end
end

# Add the extension product to the embed phase
build_file = embed_phase.add_file_reference(ext_target.product_reference)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# 7. Add extension target to the Runner scheme so it gets built
scheme_path = "#{project_path}/xcshareddata/xcschemes/Runner.xcscheme"
if File.exist?(scheme_path)
  scheme = Xcodeproj::XCScheme.new(scheme_path)
  scheme.add_build_target(ext_target)
  scheme.save!
  puts "Added TwitterShareExtension to Runner scheme"
else
  puts "WARNING: Runner.xcscheme not found at #{scheme_path}"
end

# 8. Print build phases order for debugging
puts "\nFinal Runner build phases order:"
runner_target.build_phases.each_with_index do |phase, i|
  name = phase.respond_to?(:name) ? phase.name : phase.class.name.split('::').last
  puts "  #{i}: #{name}"
end

project.save
puts "\nSuccessfully added TwitterShareExtension target!"
