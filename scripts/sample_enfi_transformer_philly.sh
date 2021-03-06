#!/usr/bin/env bash

# FIXME: Hard code here, assume that the training script in `.../ProjectRoot/ignored_scripts/` (depth = 1)
ProjectDir=$(readlink -f $(dirname ${PHILLY_CONFIG_FILE})/../ )
OutputDir=${PHILLY_INPUT_DIRECTORY}
SaveDir=${OutputDir}/checkpoints
LogDir=${OutputDir}/log
DataDir=${OutputDir}/data
BeamSize=5
LenPen=1.0
FP16=false
BatchSize=1024

Dataset=wmt19.tokenized.fi-en.joined
CkptDir=wmt19.tokenized.fi-en.joined_transformer_wmt_en_de_big_t2t_dp0.1_seed1_big_e10d10_
Ckpt=checkpoint13.pt
SourceDirPrefix=wmt19.train.mono.final
SourceFilename=part.aa

while [ "$1" != "" ]; do
	case $1 in
		--cd | --ckpt-dir )
			shift
			CkptDir=$1
			;;
		-C | --ckpt )
			shift
			Ckpt=checkpoint${1}.pt
			;;
		-D | --dataset )
			shift
			Dataset=$1
			;;
		-b | --beam )
			shift
			BeamSize=$1
			;;
		--bs | --batch-size | --max-tokens )
			shift
			BatchSize=$1
			;;
		--alpha | --lenpen )
			shift
			LenPen=$1
			;;
		--sdp | --src-dir-prefix )
			shift
			SourceDirPrefix=$1
			;;
		--src | --source )
			shift
			SourceFilename=$1
			;;
		* )
			;;
	esac
	shift
done

# Detect language automatically.
l=$(python -c "s='${Dataset}';i=s.index('-');print(s[i-2:i+3])")
src_l=$(python -c "print('${l}'.split('-')[0])")
tgt_l=$(python -c "print('${l}'.split('-')[1])")

SourceDir=${SourceDirPrefix}.${src_l}
FullSourceFile=${DataDir}/${SourceDir}/${SourceFilename}
LogFilename=${LogDir}/${CkptDir}-${Ckpt}-sample-${SourceDir}-${SourceFilename}.log.txt
OutputDir=${SaveDir}/${CkptDir}-${Ckpt}-sample/${SourceDir}
FullOutputFile=${OutputDir}/translated.${SourceFilename}

mkdir -pv ${OutputDir}
rm -v ${LogFilename}

FullSavePath=${SaveDir}/${CkptDir}/${Ckpt}

# Detect FP16 automatically.
if [[ "${CkptDir}" =~ .*fp16.* ]]; then
	FP16=true
	FP16Args="--fp16"
fi
 
# Set path.
OldPwd=$(pwd)
set -x
cd ${ProjectDir}
export PYTHONPATH="$(pwd)/.local/lib/python3.6/site-packages:${PYTHONPATH}"
set +x

echo "Sampling checkpoint ${CkptDir}/${Ckpt} on monolingual data ${FullSourceFile}, output save to ${FullOutputFile}..." | tee -a ${LogFilename}
set -x
# Generate:
# [NOTE]: Does NOT remove bpe.
python ${ProjectDir}/generate_v2.py ${DataDir}/${Dataset} \
	${FP16Args} \
    --path ${FullSavePath} \
    --max-tokens ${BatchSize} \
    --beam ${BeamSize} \
    --nbest ${BeamSize} \
    --lenpen ${LenPen} \
    --source-lang ${src_l} --target-lang ${tgt_l} \
    --quiet \
    --decode-source-file ${FullSourceFile} \
	--decode-output-file ${FullOutputFile} \
	--skip-invalid-size-inputs-valid-test \
	--decode-to-file
    2>&1 | tee -a ${LogFilename}
set +x
echo "Sampling checkpoint ${CkptDir}/${Ckpt} done." | tee -a ${LogFilename}
