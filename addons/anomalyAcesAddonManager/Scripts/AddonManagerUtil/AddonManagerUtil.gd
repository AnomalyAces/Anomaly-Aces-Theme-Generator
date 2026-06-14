@tool
class_name AddonManagerUtil extends Object

static func get_github_pat() -> GithubPATInfo:
    var pat_info: GithubPATInfo = GithubPATInfo.new()
    if AceFileUtil.File.file_exists(AcePluginGithubPATView.GITHUB_PAT_FILE_PATH):
        var file: FileAccess = AceFileUtil.File.create_file(AcePluginGithubPATView.GITHUB_PAT_FILE_PATH, FileAccess.READ)
        var content: String = file.get_as_text()
        file.close()

        var pat_res: AceDeserializeResult = AceSerialize.deserialize(content, GithubPATInfo)

        if pat_res.error != OK:
            AceLog.printLog(["Failed to deserialize PAT info from file. Error code: ", pat_res.error], AceLog.LOG_LEVEL.ERROR)
            return pat_info
        
        pat_info = pat_res.data

        if pat_info != null:
            AceLog.printLog(["Loaded Personal Access Token from file. Expiration Date: ", pat_info.expiration_date], AceLog.LOG_LEVEL.INFO)
            return pat_info
        else:
            AceLog.printLog(["Failed to deserialize Personal Access Token info from file."], AceLog.LOG_LEVEL.ERROR)
            return GithubPATInfo.new()
    else:
        AceFileUtil.File.create_file(AcePluginGithubPATView.GITHUB_PAT_FILE_PATH, FileAccess.WRITE) # Create an empty file if it doesn't exist.
        AceLog.printLog(["No existing Personal Access Token found. Please enter a token and click 'Check Token'."], AceLog.LOG_LEVEL.INFO)
        return pat_info


static func enable_addons() -> void:
    var addons_path = "res://addons/"
    var dir = DirAccess.open(addons_path)

    if dir:
        dir.list_dir_begin()
        var folder_name = dir.get_next()
        
        while folder_name != "":
            # 1. Ensure it is a directory and not a hidden file system path
            if dir.current_is_dir() and not folder_name.begins_with("."):
                
                # 2. Check if the directory actually contains a 'plugin.cfg' file
                var cfg_path = folder_name.path_join("plugin.cfg")
                if dir.file_exists(cfg_path):
                    
                    # 3. Only enable it if it isn't active already
                    if not EditorInterface.is_plugin_enabled(folder_name):
                        EditorInterface.set_plugin_enabled(folder_name, true)
                        print("Plugin enabled successfully: ", folder_name)
                    else:
                        print("Plugin already active: ", folder_name)
                else:
                    # Safely skip asset/utility folders that are not formal editor plugins
                    print("Skipped (No plugin.cfg found): ", folder_name)
                    
            folder_name = dir.get_next()
        print("All found addons processed successfully!")
    else:
        print("An error occurred trying to access the res://addons/ path.")