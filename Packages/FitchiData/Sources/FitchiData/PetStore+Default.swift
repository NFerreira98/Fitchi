import FitchiCore
import Foundation

extension PetStore {
    /// The on-disk store with the catalog bundled in the app's `Content` folder.
    public static func makeDefault(bundle: Bundle = .main, grantsStarterEgg: Bool = true) -> PetStore {
        let empty = Catalog(species: [], items: [], eggs: [], achievements: [])
        let catalog = (try? bundle.url(forResource: "Content", withExtension: nil).map(Catalog.load(from:))) ?? empty
        let repository = (try? FitchiStore.makeContainer()).map(GameRepository.init(container:))
        let store = PetStore(repository: repository, catalog: catalog)
        store.load(grantsStarterEgg: grantsStarterEgg)
        return store
    }
}
