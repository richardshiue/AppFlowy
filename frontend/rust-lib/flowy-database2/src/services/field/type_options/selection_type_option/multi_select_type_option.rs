use crate::entities::{FieldType, SelectOptionCellDataPB, SelectOptionFilterPB};
use crate::services::cell::CellDataChangeset;
use crate::services::field::{
  default_order, CellDataProtobufEncoder, SelectOptionCellChangeset, SelectTypeOptionSharedAction,
  TypeOption, TypeOptionCellDataCompare, TypeOptionCellDataFilter,
};
use crate::services::sort::SortCondition;

use collab_database::fields::select_type_option::{
  MultiSelectTypeOption, SelectOption, SelectOptionIds,
};
use collab_database::fields::TypeOptionData;
use collab_database::rows::Cell;
use flowy_error::FlowyResult;

use collab_database::template::util::ToCellString;
use std::cmp::Ordering;

impl TypeOption for MultiSelectTypeOption {
  type CellData = SelectOptionIds;
  type CellChangeset = SelectOptionCellChangeset;
  type CellProtobufType = SelectOptionCellDataPB;
  type CellFilter = SelectOptionFilterPB;
}

impl CellDataProtobufEncoder for MultiSelectTypeOption {
  fn protobuf_encode(
    &self,
    cell_data: <Self as TypeOption>::CellData,
  ) -> <Self as TypeOption>::CellProtobufType {
    self.get_selected_options(cell_data).into()
  }
}

impl SelectTypeOptionSharedAction for MultiSelectTypeOption {
  fn number_of_max_options(&self) -> Option<usize> {
    None
  }

  fn to_type_option_data(&self) -> TypeOptionData {
    self.clone().into()
  }

  fn options(&self) -> &Vec<SelectOption> {
    &self.options
  }

  fn mut_options(&mut self) -> &mut Vec<SelectOption> {
    &mut self.options
  }
}

impl CellDataChangeset for MultiSelectTypeOption {
  fn apply_changeset(
    &self,
    changeset: <Self as TypeOption>::CellChangeset,
    cell: Option<Cell>,
  ) -> FlowyResult<(Cell, <Self as TypeOption>::CellData)> {
    let insert_option_ids = changeset
      .insert_option_ids
      .into_iter()
      .filter(|insert_option_id| {
        self
          .options
          .iter()
          .any(|option| &option.id == insert_option_id)
      })
      .collect::<Vec<String>>();

    let select_option_ids = match cell {
      None => SelectOptionIds::from(insert_option_ids),
      Some(cell) => {
        let mut select_ids = SelectOptionIds::from(&cell);
        for insert_option_id in insert_option_ids {
          if !select_ids.contains(&insert_option_id) {
            select_ids.push(insert_option_id);
          }
        }

        for delete_option_id in changeset.delete_option_ids {
          select_ids.retain(|id| id != &delete_option_id);
        }

        tracing::trace!("Multi-select cell data: {}", select_ids.to_cell_string());
        select_ids
      },
    };
    Ok((
      select_option_ids.to_cell(FieldType::MultiSelect),
      select_option_ids,
    ))
  }
}

impl TypeOptionCellDataFilter for MultiSelectTypeOption {
  fn apply_filter(
    &self,
    filter: &<Self as TypeOption>::CellFilter,
    cell_data: &<Self as TypeOption>::CellData,
  ) -> bool {
    let selected_options = self.get_selected_options(cell_data.clone()).select_options;
    filter.is_visible(&selected_options).unwrap_or(true)
  }
}

impl TypeOptionCellDataCompare for MultiSelectTypeOption {
  /// Orders two cell values to ensure non-empty cells are moved to the front and empty ones to the back.
  ///
  /// This function compares the two provided cell values (`left` and `right`) to determine their
  /// relative ordering:
  ///
  /// - If both cells are empty (`None`), they are considered equal.
  /// - If the left cell is empty and the right is not, the left cell is ordered to come after the right.
  /// - If the right cell is empty and the left is not, the left cell is ordered to come before the right.
  /// - If both cells are non-empty, they are ordered based on their names. If there is an additional sort condition,
  ///   this condition will further evaluate their order.
  ///
  fn apply_cmp(
    &self,
    cell_data: &<Self as TypeOption>::CellData,
    other_cell_data: &<Self as TypeOption>::CellData,
    sort_condition: SortCondition,
  ) -> Ordering {
    match cell_data.len().cmp(&other_cell_data.len()) {
      Ordering::Equal => {
        for (left_id, right_id) in cell_data.iter().zip(other_cell_data.iter()) {
          let left = self.options.iter().find(|option| &option.id == left_id);
          let right = self.options.iter().find(|option| &option.id == right_id);
          let order = match (left, right) {
            (None, None) => Ordering::Equal,
            (None, Some(_)) => Ordering::Greater,
            (Some(_), None) => Ordering::Less,
            (Some(left_option), Some(right_option)) => {
              let name_order = left_option.name.cmp(&right_option.name);
              sort_condition.evaluate_order(name_order)
            },
          };

          if order.is_ne() {
            return order;
          }
        }
        default_order()
      },
      order => sort_condition.evaluate_order(order),
    }
  }
}

#[cfg(test)]
mod tests {
  use crate::services::cell::CellDataChangeset;
  use crate::services::field::type_options::selection_type_option::*;
  use collab_database::fields::select_type_option::{
    MultiSelectTypeOption, SelectOption, SelectOptionIds, SelectTypeOption,
  };
  use collab_database::template::util::ToCellString;

  #[test]
  fn multi_select_insert_multi_option_test() {
    let google = SelectOption::new("Google");
    let facebook = SelectOption::new("Facebook");
    let multi_select = MultiSelectTypeOption(SelectTypeOption {
      options: vec![google.clone(), facebook.clone()],
      disable_color: false,
    });

    let option_ids = vec![google.id, facebook.id];
    let changeset = SelectOptionCellChangeset::from_insert_options(option_ids.clone());
    let select_option_ids: SelectOptionIds =
      multi_select.apply_changeset(changeset, None).unwrap().1;

    assert_eq!(&*select_option_ids, &option_ids);
  }

  #[test]
  fn multi_select_unselect_multi_option_test() {
    let google = SelectOption::new("Google");
    let facebook = SelectOption::new("Facebook");
    let multi_select = MultiSelectTypeOption(SelectTypeOption {
      options: vec![google.clone(), facebook.clone()],
      disable_color: false,
    });
    let option_ids = vec![google.id, facebook.id];

    // insert
    let changeset = SelectOptionCellChangeset::from_insert_options(option_ids.clone());
    let select_option_ids = multi_select.apply_changeset(changeset, None).unwrap().1;
    assert_eq!(&*select_option_ids, &option_ids);

    // delete
    let changeset = SelectOptionCellChangeset::from_delete_options(option_ids);
    let select_option_ids = multi_select.apply_changeset(changeset, None).unwrap().1;
    assert!(select_option_ids.is_empty());
  }

  #[test]
  fn multi_select_insert_single_option_test() {
    let google = SelectOption::new("Google");
    let multi_select = MultiSelectTypeOption(SelectTypeOption {
      options: vec![google.clone()],
      disable_color: false,
    });

    let changeset = SelectOptionCellChangeset::from_insert_option_id(&google.id);
    let select_option_ids = multi_select.apply_changeset(changeset, None).unwrap().1;
    assert_eq!(select_option_ids.to_cell_string(), google.id);
  }

  #[test]
  fn multi_select_insert_non_exist_option_test() {
    let google = SelectOption::new("Google");
    let multi_select = MultiSelectTypeOption(SelectTypeOption {
      options: vec![],
      disable_color: false,
    });

    let changeset = SelectOptionCellChangeset::from_insert_option_id(&google.id);
    let (_, select_option_ids) = multi_select.apply_changeset(changeset, None).unwrap();
    assert!(select_option_ids.is_empty());
  }

  #[test]
  fn multi_select_insert_invalid_option_id_test() {
    let google = SelectOption::new("Google");
    let multi_select = MultiSelectTypeOption(SelectTypeOption {
      options: vec![google],
      disable_color: false,
    });

    // empty option id string
    let changeset = SelectOptionCellChangeset::from_insert_option_id("");
    let (cell, _) = multi_select.apply_changeset(changeset, None).unwrap();
    let option_ids = SelectOptionIds::from(&cell);
    assert!(option_ids.is_empty());

    let changeset = SelectOptionCellChangeset::from_insert_option_id("123,456");
    let select_option_ids = multi_select.apply_changeset(changeset, None).unwrap().1;
    assert!(select_option_ids.is_empty());
  }
}
