import SwiftUI

/// A search result coming from Open Food Facts.
struct RemoteFoodRow: View {
    let food: RemoteFood

    var body: some View {
        HStack(spacing: 12) {
            ProductThumbnail(url: food.imageURL)

            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.body)
                    .lineLimit(2)
                if let brand = food.brand {
                    Text(brand)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                MacroSummaryLine(facts: food.nutritionPer100g)
                Text("pour 100 g")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

/// A product already stored locally.
struct StoredProductRow: View {
    let product: FoodProduct

    var body: some View {
        HStack(spacing: 12) {
            ProductThumbnail(url: product.imageURL)

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.body)
                    .lineLimit(2)
                if let brand = product.brand {
                    Text(brand)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                MacroSummaryLine(facts: product.nutritionPer100g)
            }

            Spacer(minLength: 0)
            Image(systemName: "arrow.counterclockwise.circle")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct ProductThumbnail: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            default:
                Image(systemName: "photo")
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 48, height: 48)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
