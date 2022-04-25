#!/usr/bin/env python3

"""postprocessing of an alphafold2 run"""

from __future__ import annotations

from typing import Any, Optional
from collections.abc import Iterable
import pickle
import os
import glob
from pathlib import Path
from string import ascii_uppercase, ascii_lowercase

import matplotlib.pyplot as plt
from matplotlib.figure import Figure
import numpy

__version__ = "0.1.0"

PredictionResult = dict[str, Any]


def main(data: Iterable[tuple[str, PredictionResult]], out_dir: Optional[Path]) -> None:
    """Main function"""
    plt.rc("font", size=15)
    data = list(data)
    figs = (
        ("pLDDT", plot_plddt(data)),
        ("distogram", plot_distogram(data)),
    )
    if out_dir is not None:
        os.makedirs(out_dir, exist_ok=True)
        for label, fig in figs:
            fig.savefig(out_dir / (label + ".svg"))
    else:
        plt.show()


def load_pkl(path: Path) -> PredictionResult:
    """Load a single pkl file"""
    with open(path, "rb") as stream:
        data: PredictionResult = pickle.load(stream)
        return data


def load_pkls(path: Path) -> Iterable[tuple[str, PredictionResult]]:
    """Load output pkls from a folder"""

    for pkl_path in glob.glob(os.path.join(path, "result_*.pkl")):
        yield (
            os.path.basename(pkl_path).removeprefix("result_").removesuffix(".pkl"),
            load_pkl(Path(pkl_path)),
        )


def plot_plddt(models: Iterable[tuple[str, PredictionResult]]) -> Figure:
    """Generate svg outputs for pLDDT"""
    fig = plt.figure(figsize=(10, 6), dpi=100)

    for label, model in models:
        plt.plot(model["plddt"], label=label)

    plt.xlabel("residue nr.")
    plt.ylabel("pLDDT score")
    plt.legend()
    return fig


def plot_distogram(models: Iterable[tuple[str, PredictionResult]]) -> Figure:
    """Generate svg distogram"""
    fig = plt.figure(figsize=(10, 6), dpi=100)
    for label, model in models:
        plt.plot(model["distogram"]["logits"][-1][-1], label=label)
    plt.legend()
    return fig


def plot_paes(
    models: Iterable[tuple[str, PredictionResult]],
    seq_len: int,
    Ls: Optional[list[int]] = None,
) -> Figure:
    """Plot predicted aligned error"""
    models = list(models)
    num_models = len(models)
    fig = plt.figure(figsize=(3 * num_models, 2))
    paes = [
        model["predicted_aligned_error"][i][:seq_len]
        for i in range(seq_len)
        for _, model in models
    ]
    for n, pae in enumerate(paes):
        plt.subplot(1, num_models, n + 1)
        plt.title(f"rank_{n+1}")
        Ln = pae.shape[0]
        plt.imshow(pae, cmap="bwr", vmin=0, vmax=30, extent=(0, Ln, Ln, 0))
        if Ls is not None and len(Ls) > 1:
            plot_ticks(Ls)
        plt.colorbar()
    return fig


# def get_query_sequence_len_array():
#    return [
#        len(query_seqs_unique[i])
#        for i, cardinality in enumerate(query_seqs_cardinality)
#        for _ in range(0, cardinality)
#    ]


def plot_ticks(Ls: list[int]) -> None:
    """Plot ticks in a paes plot"""
    alphabet_list = list(ascii_uppercase + ascii_lowercase)
    Ln = sum(Ls)
    L_prev = 0
    for L_i in Ls[:-1]:
        L = L_prev + L_i
        L_prev += L_i
        plt.plot([0, Ln], [L, L], color="black")
        plt.plot([L, L], [0, Ln], color="black")
    ticks = numpy.cumsum([0] + Ls)
    ticks = (ticks[1:] + ticks[:-1]) / 2
    plt.yticks(ticks, alphabet_list[: len(ticks)])


if __name__ == "__main__":
    import argparse

    _parser = argparse.ArgumentParser(description=os.path.basename(__file__))
    _parser.add_argument(
        "-o",
        dest="out_dir",
        default=None,
        type=Path,
        help="Output folder (none - plot directly to the screen)",
    )
    _parser.add_argument(
        "data",
        type=Path,
        help="Input folder containing alphafold2 output",
    )
    _cmd_args = _parser.parse_args()

    main(data=load_pkls(_cmd_args.data), out_dir=_cmd_args.out_dir)
