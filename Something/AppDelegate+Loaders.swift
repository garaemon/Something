import Cocoa

// The loaders of the cached repository and file lists.
extension AppDelegate {
    func makeRepositoryLoader() -> BackgroundListLoader<String, GhqRepository> {
        let loader = BackgroundListLoader<String, GhqRepository>(
            queueLabel: "com.garaemon.Something.repositoryList",
            readKey: { [weak self] in self?.settings.repositoryRootPath ?? "" },
            makeLoadFunction: { [weak self] in
                let catalog = self?.repositoryCatalog
                return { rootPath in
                    catalog?.loadRepositories(URL(fileURLWithPath: rootPath, isDirectory: true))
                        ?? []
                }
            }
        )
        loader.onItemsLoaded = { [weak self] repositories in
            self?.launcherViewModel?.replaceSource(Self.makeRepositorySource(repositories))
        }
        return loader
    }

    func makeFileLoader() -> BackgroundListLoader<[String], LocalFile> {
        let loader = BackgroundListLoader<[String], LocalFile>(
            queueLabel: "com.garaemon.Something.fileList",
            readKey: { [weak self] in self?.settings.fileFolderPaths ?? [] },
            makeLoadFunction: { [weak self] in
                let catalog = self?.fileCatalog
                return { folderPaths in
                    catalog?.loadFiles(
                        folderPaths.map { URL(fileURLWithPath: $0, isDirectory: true) }
                    ) ?? []
                }
            }
        )
        loader.onItemsLoaded = { [weak self] files in
            self?.launcherViewModel?.replaceSource(Self.makeFileSource(files))
        }
        return loader
    }
}
